module Platanus

  module Cmap

    class InvalidName < Exception; end

    def self.included(base)
      base.cattr_accessor :cmap
      base.cmap = Hash.new { |hash, key| hash[key] = {} }
      base.extend ClassMethods
    end

    module ClassMethods

      def cmap_register(_key, _value, _cat=nil)
        if _cat.nil?; self.cmap[_key] = _value
        else; self.cmap[_cat.to_s][_key] = _value
        end
      end

      def cmap_convert(_key, _cat=nil)
        if _cat.nil?; return self.cmap[_key]
        else; return self.cmap[_cat.to_s][_key]
        end
      end

      def cmap_convert_back(_value, _cat=nil)
        if _cat.nil?; return self.cmap.key(_value)
        else; return self.cmap[_cat.to_s].key(_value)
        end
      end

      def str_attr_accessor(_target, _options={})
        str_attr_reader(_target,_options)
        str_attr_writer(_target,_options)
      end

      def str_attr_writer(_target, _options={})
        _target = _target.to_s
        _self = _options.fetch(:extend, self)
        _cat = _options[:cat]
        _cmap = self.cmap

        _self.send(:define_method, _target + '_str=') do |value|
          if _cat.nil?; self.send(_target + '=', _cmap.fetch(value))
          else; self.send(_target + '=', _cmap[_cat.to_s].fetch(value)); end
        end
      end

      def str_attr_reader(_target, _options={})
        _target = _target.to_s
        _self = _options.fetch(:extend, self)
        _cat = _options[:cat]
        _cmap = self.cmap

        _self.send(:define_method, _target + '_str') do
          if _cat.nil?; _cmap.key(self.send(_target))
          else; _cmap[_cat.to_s].key(self.send(_target)); end
        end
      end

      # private
      # def cmap_converters(_cat_or_name=nil)
        # # Define new class methods.
        # klass = (class << self; self; end)
        # klass.send(:define_method, _target + '_to_str') do |value|
          # if _cat.nil?; _cmap.index(value)
          # else; _cmap[_cat].index(value); end
        # end
#
        # klass.send(:define_method, 'str_to_' + _target) do |value|
          # if _cat.nil?; _cmap.fetch(value)
          # else; _cmap[_cat].fetch(value); end
        # end
      # end
    end
  end
end


