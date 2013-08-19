module EmActor
  module Pipe
    attr_reader :pid

    def initialize(pid)
      @pid    = pid
      @closed = false
    end

    def on_msg(&blk)
      @on_msg = blk
    end

    def on_close(&blk)
      @on_close = blk
      @closed && @on_close.call
    end

    def receive_data(d)
      @on_msg && @on_msg[d]
    end

    def unbind
      @closed = true
      @on_close && @on_close.call
    end

  end # module::Pipe
end #module::EmActor
