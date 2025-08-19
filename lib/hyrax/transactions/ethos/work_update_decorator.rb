# frozen_string_literal: true

# OVERRIDE Hyrax v5.0.0 to add custom relations to the change_set

module Hyrax
  module Transactions
    module Ethos
      module WorkUpdateDecorator
        # Insert transaction handler steps for processing compound fields
        def initialize(container: ::Container, steps: nil)
          steps = steps.dup.insert(steps.index('change_set.apply'), 
                                   'change_set.handle_creators',
                                   'change_set.handle_contributors')

          super
        end

      end
    end
  end
end

Hyrax::Transactions::WorkUpdate.prepend(Hyrax::Transactions::Ethos::WorkUpdateDecorator)
