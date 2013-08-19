require "em-actor/version"
require "em-actor/actor"
require "em-actor/pipe"

module EmActor
  attr_reader :actor

  class << self
    def extended(o)
      o.instance_variable_set(:@actor, Actor.new(o))
    end
  end

  def initialize(*args, &blk)
    @actor = Actor.new(self) do |a|
      super(self, *args, &blk)
      yield self if block_given?
    end
  end
end # module::EmActor
