# frozen_string_literal: true
require 'dry/monads'

module Hyrax
  module Transactions
    module Ethos
      module Steps
        ##
        # Add a given `::User` as the `#depositor` via a ChangeSet.
        # If no user is given, simply passes as a `Success`.
        #
        # @since 3.0.0
        class HandleValidateNewWork
          include Dry::Monads[:result]

          ##
          # @param [Hyrax::ChangeSet] change_set
          # @param [#user_key] user
          #
          # @return [Dry::Monads::Result]
          def call(change_set)
            # Moved validation to Bulkrax monkey patch (config/intitalizers/bulkrax.rb)
            Success(change_set)
          rescue NoMethodError => err
            Failure([err.message, change_set])
          end
        end
      end
    end
  end
end
