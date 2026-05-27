# frozen_string_literal: true

# Override Hyku ApplicationController to not ever use basic auth (N.B. no more private sites)
ApplicationController.class_eval do
  def authenticate_if_needed
    true
  end
end

Rails.application.config.exceptions_app = Rails.application.routes
