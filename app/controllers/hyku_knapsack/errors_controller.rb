# frozen_string_literal: true
module HykuKnapsack
  class ErrorsController < ApplicationController
    def not_found
      AccountElevator.switch!('ethos')
      render status: :not_found
    end

    def internal_server_error
      AccountElevator.switch!('ethos')
      render status: :internal_server_error
    end

    def rejected
      AccountElevator.switch!('ethos')
      render status: :unprocessable_entity
    end
  end
end
