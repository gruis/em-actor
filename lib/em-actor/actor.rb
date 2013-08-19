require "logger"
require "fiber"
require "em-actor/mailbox"

module EmActor
  class Actor
    class << self
      def log
        @log ||= ::Logger.new(STDERR)
      end

      def spawn(&blk)
        parent   = Process.pid
        cin, pot = IO.pipe
        pin, cot = IO.pipe

        child = EM.fork_reactor do
          pin.close
          pot.close
          mbox = Mailbox.new(cin, cot, parent)
          yield mbox if block_given?
        end

        Process.exit if child.nil?
        cin.close
        cot.close
        return Mailbox.new(pin, pot, child)
      end

      # Block the current Fiber while waiting for all the provided Actors to exit.
      def join(*actors)
        f       = Fiber.current
        waiting = actors.flatten.clone
        waiting.clone.each do |actor|
          [:errback, :callback].each do |event|
            actor.public_send(event) do |res|
              waiting.delete(actor)
              if :errback == event
                log.warn "#{actor} encountered an error: #{res}"
              else
                log.info "#{actor} has finished"
              end
              log.info "  waiting for #{waiting.length} actors"
              # TODO call resume with the result of the callbacks, errbacks, etc.,
              f.resume if waiting.empty?
            end
          end
        end
        Fiber.yield.tap do |e|
          raise e if e.is_a?(Exception)
        end
      end
    end

    include EM::Deferrable

    attr_reader :pid

    attr_reader :closing
    alias :closing? :closing
    attr_writer :closing
    private :closing=

    def initialize(obj, &blk)
      parent       = Process.pid
      @rep_cbs     = {}
      @send_buffer = ""
      @recv_buffer = ""

      mailbox = self.class.spawn do |childbox|
        childbox.on_msg(&method(:recv))
        @obj     = obj
        @mailbox = childbox
        exit_with_parent
        yield(self) if block_given?
      end

      @pid = mailbox.pid
      mailbox.on_msg(&method(:recv))
      mailbox.inbox.on_close do
        closing? ?
          succeed :
          fail("child process #{@pid} has died")
      end
      @obj     = obj
      @mailbox = mailbox
      @msg_idx = 0
      flush
    end

    def log
      self.class.log
    end

    # @return [Fixnum] message id
    def send(meth, *args)
      log.debug "send(#{meth.inspect}, #{args.inspect})"
      mid = @msg_idx
      @msg_idx += 1
      body = Marshal.dump([meth, args])
      pckt = "req:#{mid}:#{body.length}:#{body}"
      if !@mailbox
        @send_buffer << pckt
      else
        @mailbox.send_data(pckt)
      end
      mid
    end

    def send!(meth, *args)
      f = Fiber.current
      @rep_cbs[send(meth, *args)] = proc { |result| f.resume(result) }
      Fiber.yield
    end

    # Register a block to be called later when a response is received to the
    # given message id. If #receive is not called immediately after calling
    # #send it is possible to miss the response.
    # @see #send
    def receive(mid, &blk)
      @rep_cbs[mid] = blk if block_given?
    end

    def flush
      unless @send_buffer.empty?
        sbuf, @send_buffer = @send_buffer, ""
        @mailbox.send_data(sbuf)
      end
      unless @recv_buffer.empty?
        rbuf, @recv_buffer = @recv_buffer, ""
        recv(rbuf)
      end
    end

    # Tell the child to stop and exit.
    def stop
      closing = true
      send_cmd(:exit)
      @mailbox && @mailbox.outbox.close_connection
    end

    # Track the parent process's status and exit if when it does.
    def exit_with_parent
      @mailbox.on_close do
        log.info "#{Process.pid} Parent side #{@mailbox.pid} of pipe has closed"
        Process.exit
      end
    end

    # If the parent process exits, don't exit
    def no_exit_with_parent
      @mailbox.on_close do
        log.info "parent (#{@mailbox.pid}) has closed"
      end
    end

    # Send a command to the wrapper of the object in the child. Only public methods can be called.
    def send_cmd(meth, *args)
      log.info "send_cmd(#{meth.inspect}, #{args.inspect})"
      mid = @msg_idx
      @msg_idx += 1
      body = Marshal.dump([meth, args])
      pckt = "cmd:#{mid}:#{body.length}:#{body}"
      if !@mailbox
        @send_buffer << pckt
      else
        @mailbox.send_data(pckt)
      end
      mid
    end

    # @api private
    def exit
      Process.exit
    end

    private


    def recv(msg)
      log.debug "recv(#{msg.inspect})"
      @recv_buffer << msg
      return unless @obj
      type, mid, body, @recv_buffer = next_msg(@recv_buffer)

      while !body.empty?
        body = Marshal.load(body)
        if type == :req
          log.error "request: #{body[0]}"
          result = @obj.public_send(body[0], *body[1]) rescue $!
          log.error "replying to #{mid}"
          reply(mid, result)

        elsif type == :rep
          if @rep_cbs[mid]
            @rep_cbs[mid][body]
            @rep_cbs.delete(mid)
          end

        elsif type == :cmd
          result = public_send(body[0], *body[1]) rescue $!
          reply(mid, result)

        else
          raise ArgumentError.new("msg type (#{type.inspect}) not recognized")
        end

        type, mid, body, @recv_buffer = next_msg(@recv_buffer)
      end
    rescue => e
      log.error("#{e}\n  #{e.backtrace.join("\n  ")}")
    end

    def next_msg(msg)
      return [nil, -1, "", msg] if msg.nil? || msg.empty? || msg.count(":") < 3
      type, mid, len, rem = msg.split(":", 4)
      len = len.to_i
      return [nil, -1, "", msg] if rem.length < len
      [type.intern, mid.to_i, rem[0..len], rem[len + 1 .. -1] || ""]
    end

    def reply(mid, data)
      result = Marshal.dump(data)
      @mailbox.send_data("rep:#{mid}:#{result.length}:#{result}")
    end
  end # class::Actor
end ## module::EmActor
