# onetime.rb : One time setter.
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Kernel

  # Creates a one time writer method.
  #
  # A one time writer is undefined after the first time it is used.
  #
  # * *Args*    :
  #   - +_name+ -> Attribute name.
  #
  def onetime_attr_writer(_name)
    define_method _name.to_s + '=' do |_value|
      instance_variable_set('@' + _name.to_s, _value)
      # Unset method by modifying singleton class.
      metaclass = (class << self; self; end)
      metaclass.send(:undef_method,_name.to_s + '=')
      _value
    end
  end

  # Adds a one time writer instead of a regular writer.
  #
  # * *Args*    :
  #   - +_name+ -> Attribute name.
  #
  def onetime_attr_accessor(_name)
    attr_reader(_name)
    onetime_attr_writer(_name)
  end
end