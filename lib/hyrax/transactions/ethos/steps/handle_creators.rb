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
        class HandleCreators
          include Dry::Monads[:result]
  
          ##
          # @param [Hyrax::ChangeSet] change_set
          # @param [#user_key] user
          #
          # @return [Dry::Monads::Result]
          def call(change_set)
            creators=[]
            ['creator_family_name', 'creator_given_name', 'creator_orcid', 'creator_isni'].each do | creator_field |
              change_set.input_params[creator_field].each_with_index do | value, index |
                creators[index]={} if creators[index].nil?
                creators[index][creator_field] = value
              end
            end
            debugger
            change_set.creator = creators.map(&:to_s)
            STDERR.puts "creators: #{change_set.creator}"
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
