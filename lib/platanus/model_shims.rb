# model_shims.rb : ActiveRecord model shims.
#
# Copyright April 2013, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  ## Shim extension for active record models
  #
  # Provide the **shims_for** class method that generates getters and setters
  # for every accesible attribute in another model and makes them accesible too (shims).
  #
  # Values stored using the shims can then be accessed using the _shims_changed?
  # and _shims_flush methods.
  #
  module ModelShims

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      ## Generate shims for a given model.
      #
      # @params [Hash] _options Options:
      # * class_name: if given, the shims model class name, if no the camelize _name is used.
      # * prefix: prefix to be used in shims, defaults to ''.
      # * proxy: an attribute to be proxied, if given then getter shims will return the proxie's
      # value for the property if not set.
      # * sync_to: same as proxy, but also call proxy_will_change! if any shimmed attribute is set.
      #
      def shims_for(_name, _options={})

        # TODO: detect if _name is an association and use the association's settings.
        # TODO: overriding options.

        name = _name.to_s
        model = _options.fetch(:class_name, name.camelize).constantize
        cache_var = _options.fetch :into, "@_#{name}_shims"
        prefix = _options[:prefix]
        sync_to = _options[:sync_to]
        sync_to_fk = self.reflections[sync_to.to_sym].foreign_key if sync_to
        proxy = _options.fetch :proxy, sync_to

        model.accessible_attributes.each do |attr_name|

          full_attr_name = if prefix then "#{prefix}#{attr_name}" else attr_name end

          if method_defined? full_attr_name
            Rails.logger.warn "shims_for: overriding getter for #{full_attr_name} in #{self.to_s}"
          end

          if method_defined? "#{full_attr_name}="
            Rails.logger.warn "shims_for: overriding setter for #{full_attr_name} in #{self.to_s}"
          end

          # override getter
          define_method full_attr_name do
            cache = instance_variable_get(cache_var)
            return cache[attr_name] if cache and cache.has_key? attr_name
            if proxy
              child = send(proxy)
              if child then child.send(attr_name) else nil end
            end
          end

          # override setter
          define_method "#{full_attr_name}=" do |value|
            cache = instance_variable_get(cache_var)
            cache = instance_variable_set(cache_var, {}) if cache.nil?
            cache[attr_name] = value
            send "#{sync_to_fk}_will_change!" if sync_to # force update if synced
          end
          attr_accessible full_attr_name

        end

        define_method("#{name}_shims_changed?") do
          not instance_variable_get(cache_var).nil?
        end

        define_method("#{name}_shims_flush") do
          cache = instance_variable_get(cache_var)
          instance_variable_set(cache_var, nil)
          return cache
        end
      end
    end
  end
end
