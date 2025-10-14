# frozen_string_literal: true
require 'dry/monads'

module Hyrax
  module Transactions
    module Ethos
      module Steps
        ##
        # Add a given `::User` as the `#depositor` via a ChangeSet.
        #
        # If no user is given, simply passes as a `Success`.
        #
        # @since 3.0.0
        class HandleFunders
          include Dry::Monads[:result]

          ##
          # @param [Hyrax::ChangeSet] change_set
          # @param [#user_key] user
          #
          # @return [Dry::Monads::Result]
          def call(change_set)
            funders = []
            debugger
            change_set.input_params['funder']&.each_with_index do | funder, index |
              next if funder['funder_name'].blank?
              funders[index] = {} if funders[index].nil?
              funders[index]=funder
            end
            debugger
            change_set.funder = funders.map(&:to_s)
            STDERR.puts "funders: #{change_set.funder}"
            debugger
            Success(change_set)
          rescue NoMethodError => err
            Failure([err.message, change_set])
          end
        end
      end
    end
  end
end
