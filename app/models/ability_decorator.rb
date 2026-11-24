# frozen_string_literal: true

# OVERRIDE Hyku f57c5a9 Ability: registers Bulkrax's importer/exporter CanCan rules and limits importer creation to admins.
#   Remove once the hyrax-webapp submodule includes samvera/hyku#3395 and admin-only creation is handled there.
unless defined?(Hyrax::Ability::BulkraxAbility)
  Ability.class_eval do
    include ::Bulkrax::AbilityBehavior

    %i[bulkrax_default_abilities restrict_importer_creation].each do |rule|
      self.ability_logic += [rule] unless ability_logic.include?(rule)
    end

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
end
