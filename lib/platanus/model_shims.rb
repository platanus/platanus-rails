# api_boilerplate.rb : ActiveRecord Activable mod.
#
# Copyright July 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # # Boilerplate for platanus json api controllers
  #
  # Provides base error handling and rendering methods.
  # Also provides a couple of opt-in behaviours..
  #
  module ModelShims

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def shims_for(_name, _options={})

        # TODO: detect if _name is an association and use the association's settings.
        # TODO: separate in attr_composite_writer and attr_composite_reader

        name = _name.to_s
        model = _options.fetch(:class_name, name.camelize).constantize
        prefix = _options.fetch :prefix, name
        cache_var = _options.fetch :into, "@_#{name}_shims"

        model.accessible_attributes.each do |attr_name|

          full_attr_name = if prefix then "#{prefix}_#{attr_name}" else attr_name end

          unless method_defined? "#{full_attr_name}="
            define_method "#{full_attr_name}=" do |value|
              cache = instance_variable_get(cache_var)
              cache = instance_variable_set(cache_var, {}) if cache.nil?
              cache[attr_name] = value
            end
            attr_accessible full_attr_name
          else
            Rails.logger.warn "shims_for: failed to generate setter for #{full_attr_name} in #{self.to_s}"
          end

          unless method_defined? full_attr_name
            define_method full_attr_name do
              cache = instance_variable_get(cache_var)
              return cache[attr_name] if cache and cache.has_key? attr_name
              child = send(name)
              if child then child.send(attr_name) else nil end
            end
          else
            Rails.logger.warn "shims_for: failed to generate getter for #{full_attr_name} in #{self.to_s}"
          end
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
