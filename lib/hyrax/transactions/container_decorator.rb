# frozen_string_literal: true

# OVERRIDE Hyrax v5.0.0 to add custom relations to the change_set

require_dependency '../lib/hyrax/transactions/ethos/steps/handle_creators'
require_dependency '../lib/hyrax/transactions/ethos/steps/handle_contributors'
require_dependency '../lib/hyrax/transactions/ethos/steps/handle_funders'

module Hyrax
  module Transactions
    module ContainerDecorator
      extend Dry::Container::Mixin

      namespace 'change_set' do |ops|
        ops.register "handle_creators" do
          Hyrax::Transactions::Ethos::Steps::HandleCreators.new
        end
        ops.register "handle_contributors" do
          Hyrax::Transactions::Ethos::Steps::HandleContributors.new
        end
        ops.register "handle_funders" do
          Hyrax::Transactions::Ethos::Steps::HandleFunders.new
        end
      end
    end
  end
end

Hyrax::Transactions::Container.merge(Hyrax::Transactions::ContainerDecorator)
