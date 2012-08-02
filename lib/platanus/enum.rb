# enum.rb : ActiveRecord Enumerated Attributes.
#
# Copyright August 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  ## Adds +attr_enum+ property generator to a module.
  #
  # When attr_enum is called on one of the model properties name:
  # * A getter and setter for the <name>_str property are added, this allows the property to be accessed as a string,
  # the string representations are obtained from the enumeration module's constants ::downcased:: names.
  # * An inclusion validation is added for the property, only values included in the enumeration module's constants are allowed
  #
  # Given the following configuration:
  #
  #    module Test
  #      ONE = 1
  #      TWO = 2
  #      THREE = 3
  #    end
  #
  #    class Model
  #      include Platanus::Enum
  #
  #      attr_enum :target, Test
  #    end
  #
  # One could do:
  #
  #    t = Model.new
  #    t.target = Test.ONE
  #    t.target_str = 'one' # Same as above
  #    t.target = 5 # Generates a validation error
  #    t.target_str =  # Raises an InvalidEnumName exception
  #
  module Enum

    # Exception risen when an invalid value is passed to one of the _str= setters.
    class InvalidEnumName < Exception; end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def attr_enum(_target, _module, _options={})

        map = {}
        pname = _options.has_key?(:property_name) ? _options[:property_name] : (_target.to_s + '_str')

        # Extract module constants
        _module.constants.each { |cname| map[_module.const_get(cname)] = cname.to_s.downcase }

        # Add string getter
        self.send(:define_method, pname) do
          map.fetch(self.send(_target), '')
        end

        # Add string setter
        self.send(:define_method, pname + '=') do |value|
          map.each_pair do |k,v|
            if v == value
              self.send(_target.to_s + '=', k)
              return
            end
          end
          raise InvalidEnumName
        end

        # Add value validator (unless validation is disabled)
        self.validates _target, inclusion: { :in => map.keys } if _options.fetch(:validate, true)
      end
    end
  end
end


