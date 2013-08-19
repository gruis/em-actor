module EmActor
  # DynDispatch is a mixin for EmActor::Actor instances.
  module DynDispatch

    def methods
      super | @obj.send!(:methods)
    end

    def respond_to?(meth)
      super(meth) || @obj.send!(:respond_to?, meth)
    end

    def method_missing(meth, *args, &blk)
      @obj.send!(meth, *args, &blk)
    end
  end # module DynDispatch
end # module::EmActor
