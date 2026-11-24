# frozen_string_literal: true

# OVERRIDE Hyku f57c5a9 Ability: registers Bulkrax's importer/exporter CanCan rules and limits importer creation to admins.
#   Remove once the hyrax-webapp submodule includes samvera/hyku#3395 and admin-only creation is handled there.
module AbilityDecorator
  def can_admin_importers?
    admin?
  end

  def can_admin_exporters?
    admin?
  end

  def restrict_importer_creation
    cannot :create, Bulkrax::Importer unless can_admin_importers?
  end
end

unless defined?(Hyrax::Ability::BulkraxAbility)
  Ability.include ::Bulkrax::AbilityBehavior
  Ability.prepend AbilityDecorator

  %i[bulkrax_default_abilities restrict_importer_creation].each do |rule|
    Ability.ability_logic += [rule] unless Ability.ability_logic.include?(rule)
  end
end
