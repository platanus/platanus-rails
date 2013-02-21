# gcontroller.rb : ActionController global access.
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

class Platanus::NotInRequestError < Exception; end

# This makes the current request controller globally avaliable.
class ActionController::Base
  around_filter :wrap_store_controller

  def wrap_store_controller
    # We could do this instead: http://coderrr.wordpress.com/2008/04/10/lets-stop-polluting-the-threadcurrent-hash/
    Thread.current[:controller] = self
    begin; yield
    ensure; Thread.current[:controller] = nil
    end
  end

  # Gets the current controller.
  #
  # * *Raises* :
  #   - +Platanus::NotInRequestError+ -> If current controller instance is not avaliable.
  def self.current
    Thread.current[:controller] # || (raise Platanus::NotInRequestError, 'Current controller not loaded')
  end
end
