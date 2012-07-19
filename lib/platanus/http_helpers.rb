# http_helpers.rb : Various HTTP Related helpers
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  ## HTTP STATUS EXCEPTIONS

  # Allows to use an exception driven scheme to notify
  # the request that a especial status should be send
  # back to the client. Usefull when used with rescue_from.
  class StatusError < StandardError

    class << self
      instance_variable_set(:@status, nil)
      instance_variable_set(:@msg, nil)
    end

    def self.setup(_status, _msg)
      @status = _status
      @msg = _msg
    end

    def self.status; @status; end
    def self.message; @msg; end

    def self.as_json(_options={})
      { 'status' => @status.to_s, 'msg' => @msg }
    end

    def initialize(_msg=nil)
      @msg = _msg
    end

    def status; self.class.status; end
    def message; if @msg.nil? then self.class.message else @msg end; end
    def as_json(_options={})
      { 'status' => status.to_s, 'msg' => message }
    end
  end

  class StatusNotFound < StatusError
    setup :not_found, 'Not found'
  end

  class StatusUnauthorized < StatusError
    setup :unauthorized, 'Not authorized'
  end

  class StatusUnprocessable < StatusError
    setup :unprocessable_entity, 'Invalid object'
  end

  class StatusBadRequest < StatusError
    setup :bad_request, 'Invalid parameters'
  end

  class StatusConflict < StatusError
    setup :conflict, 'Model conflict'
  end
end