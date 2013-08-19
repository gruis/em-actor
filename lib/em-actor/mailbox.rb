require "em-actor/pipe"
module EmActor
  class Mailbox
    attr_reader :inbox
    attr_reader :outbox
    attr_reader :pid
    attr_reader :out_fd
    attr_reader :in_fd

    def initialize(pin, pot, pid)
      @pid     = pid
      @inbox   = EventMachine.attach(pin, Pipe, pid)
      @outbox  = EventMachine.attach(pot, Pipe, pid)
      @in_fd   = pin
      @out_fid = pot
    end

    # Register a block to be called when a message is received on the inbox.
    def on_msg(&blk)
      @inbox.on_msg(&blk)
    end

    # Send data to the outbox
    def send_data(d)
      @outbox.send_data(d)
    end

    # Register a block to be called when the inbox closes.
    def on_close(&blk)
      @inbox.on_close(&blk)
    end
  end
end
