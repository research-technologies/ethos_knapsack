# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:user) { create(:user) }

  it 'runs the Bulkrax ability rules' do
    expect(described_class.ability_logic).to include(:bulkrax_default_abilities, :restrict_importer_creation)
  end

  context 'when the user is an admin' do
    let(:user) { create(:admin) }

    it { is_expected.to be_able_to(:new, Bulkrax::Importer.new) }
    it { is_expected.to be_able_to(:read, Bulkrax::Importer) }
    it { is_expected.to be_able_to(:manage, Bulkrax::Exporter) }
  end

  context 'when the user can deposit but is not an admin' do
    before do
      allow_any_instance_of(described_class).to receive(:can_create_any_work?).and_return(true) # rubocop:disable RSpec/AnyInstance
    end

    it { is_expected.not_to be_able_to(:new, Bulkrax::Importer.new) }
    it { is_expected.not_to be_able_to(:create, Bulkrax::Importer.new) }
    it { is_expected.to be_able_to(:read, Bulkrax::Importer.new(user_id: user.id)) }
  end
end
