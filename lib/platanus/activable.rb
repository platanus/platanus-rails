# activable.rb : ActiveRecord Activable mod.
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # When included in a model definition, this module
  # provides soft delete capabilities via the +remove+ method.
  #
  # This module also defines a +remove+ callback.
  #
  module Activable
    def self.included(base)
      base.define_callbacks :remove
      base.attr_protected :removed_at
      base.send(:default_scope, base.where(:removed_at => nil))
      base.extend ClassMethods
    end

    module ClassMethods
      # Executes a mass remove, this wont call any callbacks!
      def remove_all
        # TODO: Find a way of doing mass updates and also call callbacks
        # self.update_all(:removed_at => DateTime.now)
        # For now, just call remove on each item
        self.all.each { |item| item.remove! }
      end

      ## Shorthand method for adding callbacks before item removal
      def before_remove(_callback)
        self.set_callback :remove, :before, _callback
      end

      ## Shorthand method for adding callbacks after item removal
      def after_remove(_callback)
        self.set_callback :remove, :after, _callback
      end
    end

    # Returns true if object hasnt been removed.
    def is_active?
      self.removed_at.nil?
    end

    # Deactivates a single record.
    def remove!
      self.transaction do
        run_callbacks :remove do

          # TODO: disable update callbacks and validations!

          # Retrieve dependant properties and remove them.
          self.class.reflect_on_all_associations.select do |assoc|
            if assoc.options[:dependent] == :destroy
              collection = self.send(assoc.name)
              collection.remove_all if collection.respond_to? :remove_all
            end
          end

          self.removed_at = DateTime.now
          self.save!
        end
      end
    end
  end

  ## Same as Activable but defines an 'alive' scope and no default scope.
  module ActivableExplicit
    def self.included(base)
      base.define_callbacks :remove
      base.attr_protected :removed_at
      base.send(:scope, 'alive', base.where(:removed_at => nil))
      base.extend Platanus::Activable::ClassMethods
    end
  end
end


