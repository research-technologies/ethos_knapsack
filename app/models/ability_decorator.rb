# frozen_string_literal: true

# OVERRIDE Hyku f57c5a9 Ability: registers Bulkrax's importer/exporter CanCan rules, which admins need to open /importers.
#   Remove once the hyrax-webapp submodule includes samvera/hyku#3395.
unless defined?(Hyrax::Ability::BulkraxAbility)
  Ability.class_eval do
    include ::Bulkrax::AbilityBehavior

    self.ability_logic += [:bulkrax_default_abilities] unless ability_logic.include?(:bulkrax_default_abilities)

    def can_admin_importers?
      admin?
    end

    def can_admin_exporters?
      admin?
    end
  end
end
