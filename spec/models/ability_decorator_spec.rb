# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:user) { build_stubbed(:user) }

  it 'runs the Bulkrax ability rules' do
    expect(described_class.ability_logic).to include(:bulkrax_default_abilities)
  end

  context 'when the user is an admin' do
    before { allow(user).to receive(:admin?).and_return(true) }

    it { is_expected.to be_able_to(:new, Bulkrax::Importer.new) }
    it { is_expected.to be_able_to(:read, Bulkrax::Importer) }
    it { is_expected.to be_able_to(:manage, Bulkrax::Exporter) }
  end
end
