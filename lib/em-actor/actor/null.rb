require "em-actor/actor"

module EmActor
  class Actor
    class Null < Actor
      def initialize(obj, &blk)
        @obj     = obj.clone
        @msg_idx = 0
        @rep_cbs = {}
        @send_buffer = ""
        @recv_buffer = ""
        @pid     = Process.pid + 2
        EM::Timer.new(0.2) { yield(self) } if block_given?
      end

      def send(meth, *args)
        mid = @msg_idx
        @msg_idx += 1
        EM::Timer.new(0.1) do
          Fiber.new {
            result = Marshal.dump(@obj.public_send(meth, *args)) rescue $!
            recv("rep:#{mid}:#{result.length}:#{result}")
          }.resume
        end
        mid
      end

      def flush
      end

      def stop
        succeed
      end

    end # class::Null
  end # class::Actor
end ## module::EmActor
