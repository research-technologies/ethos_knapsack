# frozen_string_literal: true

# OVERRIDE Hyrax v5.0.0 to add custom relations to the change_set

module Hyrax
  module Transactions
    module Ethos
      module WorkCreateDecorator
        def initialize(container: ::Container, steps: nil)
          steps = steps.dup.insert(steps.index('change_set.apply'), 'change_set.handle_creators')
          super
        end
      end
    end
  end
end
Hyrax::Transactions::WorkCreate.prepend(Hyrax::Transactions::Ethos::WorkCreateDecorator)
