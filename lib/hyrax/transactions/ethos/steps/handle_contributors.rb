# frozen_string_literal: true
require 'dry/monads'

module Hyrax
  module Transactions
    module Ethos
      module Steps
        ##
        # Add a given `::User` as the `#depositor` via a ChangeSet.
        # If no user is given, simply passes as a `Success`.
        # @since 3.0.0
        class HandleContributors
          include Dry::Monads[:result]

          ##
          # @param [Hyrax::ChangeSet] change_set
          # @param [#user_key] user
          #
          # @return [Dry::Monads::Result]
          # rubocop:disable Metrics/MethodLength
          def call(change_set)
            contributors = []
            updated = false
            ['contributor_role', 'contributor_family_name', 'contributor_given_name'].each do |contributor_field|
              updated = true if change_set.input_params.key?(contributor_field)
              next if change_set.input_params[contributor_field].blank?
              change_set.input_params[contributor_field].each_with_index do |value, index|
                contributors[index] = {} if contributors[index].nil?
                contributors[index][contributor_field] = value
              end
            end
            if updated
              change_set.contributor = contributors.map(&:to_s)
              change_set.contributor_search = contributors.map { |c| "#{c['contributor_given_name']} #{c['contributor_family_name']}" }
            end
            Success(change_set)
          rescue NoMethodError => err
            Failure([err.message, change_set])
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
