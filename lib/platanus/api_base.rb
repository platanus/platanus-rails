# api_boilerplate.rb : ActiveRecord Activable mod.
#
# Copyright July 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # # Boilerplate for platanus json api controllers
  #
  # Provides base error handling and rendering methods.
  # Also provides a couple of opt-in behaviours..
  #
  module ApiBoilerplate

    def self.included(base)

      base.respond_to :json # Respond to json by default.

      ## EXCEPTION HANDLING

      base.rescue_from 'Exception' do |exc|
        logger.error exc.message
        logger.error exc.backtrace.join("\n")
        api_respond_error(:internal_server_error, { msg: 'server_error', exception: { type: exc.class.to_s, msg: exc.message } } )
      end

      base.rescue_from 'ActiveRecord::RecordNotFound' do |exc|
        api_respond_error(:not_found, { msg: 'record_not_found', detail: exc.message })
      end

      base.rescue_from 'ActiveModel::MassAssignmentSecurity::Error' do |exc|
        api_respond_error(:bad_request, { msg: 'protected_attributes', detail: exc.message } )
      end

      base.rescue_from 'ActiveRecord::RecordInvalid' do |exc|
        api_respond_error(:bad_request, { msg: 'invalid_attributes', errors: exc.record.errors } )
      end

      # Platanus error support
      base.rescue_from 'Platanus::StatusError' do |exc|
        api_respond_error(exc.status, { msg: exc.message })
      end

      # Canned error support
      base.rescue_from 'Platanus::Canned2::AuthError' do |exc|
        api_respond_error(:unauthorized, { msg: 'canned' })
      end

      base.extend ClassMethods
      base.send :include, InstanceMethods
    end
  end

  module ClassMethods

    # # Enables dumb object wrapping
    #
    # When enabled, every request parameter is wrapped in a user defined key.
    # You should disable default parameter wrapping when using this.
    # (look at wrap_parameter.rb file for more information on how to disable parameter wrapping)
    #
    # @param [Symbol] _key Params key to store parameters in (defaults to :object)
    #
    def dumb_wrapping(_key=:object)
      self.before_filter do
        # Disable magic parameter wrapping (at env) and use 'object' key to hold
        # incomming request parameters.
        return if request.headers['HTTP_USER_AGENT'] == 'Rails Testing'
        params[:object] = request.request_parameters
      end
    end

    # # Enables cors
    def enable_cors
      # TODO: maybe cors support should be implemented as a middleware.
      # response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With,Content-Type'
      # response.headers['Access-Control-Allow-Methods'] = 'OPTIONS,GET,HEAD,POST,PUT,DELETE'
      # response.headers['Access-Control-Allow-Origin'] = '*'
    end

  end

  module InstanceMethods

    # # Renders an empty response
    def api_respond_empty(_options={})
      _options[:json] = {}
      api_respond_with(_options)
    end

    # # Renders a regular response
    def api_respond_with(*_params)
      if _params.last.is_a? Hash
        _options = _params.last
        _params = _params[0...-1]
      else
        _options = {}
      end

      respond_with(*_params) do |format|
        format.json { render _options }
      end
    end

    # # Renders an error response
    #
    # @param [String, Fixnum] _status Response error code.
    # @param [object] _error_obj Error object to serialize in response.
    #
    def api_respond_error(_status, _error_obj={})
      respond_with do |format|
        format.json { render :status => _status, :json => _error_obj }
      end
    end

  end
end
