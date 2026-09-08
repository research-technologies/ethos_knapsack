# frozen_string_literal: true

# OVERRIDE Hyku 7.1 to remove the basic auth check for non-public sites (requirement to clear BL security hurdle)
module Hyku
  module ApplicationControllerDecorator
    def authenticate_if_needed
      # Disable this extra authentication all the time for EThOS
      return true
    end
  end
end

ApplicationController.prepend(Hyku::ApplicationControllerDecorator) 
