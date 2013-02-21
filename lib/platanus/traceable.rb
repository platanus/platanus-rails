# traceable.rb : Logged user action tracing
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # When included in a model, this module will provide seamless C(R)UD operations
  # tracing.
  #
  # This module operates under a couple of conventions:
  # * When a new operation is detected it will look for the +user_id+ method for the current controller
  # and assing it's value to the <action>_by attribute of the current model.
  # * When a new operation is detected the controllers +trace+ method is called passing the action and
  # the current model.
  #
  # This module will also trace +Activable.remove+ calls.
  # Will only work if the gcontroller mod is active.
  #
  module Traceable

    def self.included(base)
      # Make sure gcontroller was loaded.
      unless ActionController::Base.respond_to? :current
        # TODO: better warning!
        base.logger.warn 'gcontroller not loaded, tracing disabled'
        return
      end

      base.around_create :__trace_create
      base.around_update :__trace_update
      base.around_destroy :__trace_destroy
      # Activable support (remove event).
      begin; base.set_callback :remove, :around, :__trace_remove; rescue; end
    end

    ## CALLBACKS

    def __trace_create # :nodoc:
      controller = ActionController::Base.current
      if controller and controller.respond_to? :trace_user_id and self.respond_to? :created_by=
        self.created_by = controller.trace_user_id
      end
      yield
      controller.trace(:create, self) if controller and controller.respond_to? :trace
    end

    def __trace_update # :nodoc:
      controller = ActionController::Base.current
      if controller and controller.respond_to? :trace_user_id and self.respond_to? :updated_by=
        self.updated_by = controller.trace_user_id
      end
      yield
      controller.trace(:update, self) if controller and controller.respond_to? :trace
    end

    def __trace_destroy # :nodoc:
      controller = ActionController::Base.current
      if controller and controller.respond_to? :trace_user_id and self.respond_to? :destroyed_by=
        self.destroyed_by = controller.trace_user_id
      end
      yield
      controller.trace(:destroy, self) if controller and controller.respond_to? :trace
    end

    def __trace_remove # :nodoc:
      controller = ActionController::Base.current
      if controller and controller.respond_to? :trace_user_id and self.respond_to? :removed_by=
        self.removed_by = controller.trace_user_id
      end
      yield
      controller.trace(:remove, self) if controller and controller.respond_to? :trace
    end
  end
end
