# app/controllers/errors_controller.rb

module HykuKnapsack
  class ErrorsController < ApplicationController
    def not_found
      AccountElevator.switch!('ethos')
      render status: 404
    end

    def internal_server_error
      AccountElevator.switch!('ethos')
      render status: 500
    end

    def rejected
      AccountElevator.switch!('ethos')
      render status: 422
    end

  end
end
