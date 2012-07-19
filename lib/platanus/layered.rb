module Platanus

  # Adds simple proxy capabilities to a class, allowing
  # it instances to wrap other objects transparently
  module Layered
    attr_reader :lo_target

    def initialize(_entity)
      @lo_target = _entity
    end

    def respond_to?(_what)
      return true if super(_what)
      return @lo_target.respond_to? _what
    end

    def method_missing(_method, *_args, &_block)
      @lo_target.send(_method, *_args, &_block)
    end
  end
end


