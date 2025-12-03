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
            debugger
            missing_fields=[]
            required_fields = ['title', 'creator', 'qualification_name', 'qualification_level', 'current_he_institution', 'date_issued', 'language', 'oai_identifier']
            required_fields.each do | required_field |
              missing_fields << required_field if change_set.input_params[required_field].blank?
            end
            raise StandardError, "The following required fields are absent: #{missing_fields.join(', ')}" if missing_fields.count > 0
            Success(change_set)
          rescue NoMethodError => err
            Failure([err.message, change_set])
          end
        end
      end
    end
  end
end
