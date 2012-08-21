# http_helpers.rb : Various HTTP Related helpers
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  ## HTTP STATUS EXCEPTIONS

  # Allows to use an exception driven scheme to notify
  # the request that a especial status should be send
  # back to the client.
  # Usefull when used with +api_base+ or +rescue_from+.
  class StatusError < StandardError

    class << self
      instance_variable_set(:@status, nil)
    end

    def self.setup(_status)
      @status = _status
    end

    def self.status; @status; end
    def self.message; "status_#{@status.to_s}"; end

    def initialize(_msg=nil)
      @msg = _msg
    end

    def status; self.class.status; end
    def message; if @msg.nil? then self.class.message else @msg end; end
  end

  class StatusNotFound < StatusError
    setup :not_found
  end

  class StatusUnauthorized < StatusError
    setup :unauthorized
  end

  class StatusUnprocessable < StatusError
    setup :unprocessable_entity
  end

  class StatusBadRequest < StatusError
    setup :bad_request
  end

  class StatusConflict < StatusError
    setup :conflict
  end
end