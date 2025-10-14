# frozen_string_literal: true

# Use this to override any Bulkrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Bulkrax.setup do |config|
    config.parsers += [
      { name: " XML - UKETD DC Parser", class_name: "Bulkrax::XmlEtdDcParser", partial: "xml_fields" }
    ]

    #    config.fill_in_blank_source_identifiers = ->(obj, index) { "#{Site.instance.account.name}-#{obj.importerexporter.id}-#{index}" }
  end
  Bulkrax::Importer::DEFAULT_OBJECT_TYPES = ['work'].freeze
end

Bulkrax::ObjectFactoryInterface.base_permitted_attributes += [:creator_family_name, :creator_given_name, :creator_isni, :creator_orcid, :contributor_role, :contributor_family_name, :contributor_given_name, :funder_name, :funder_award]

# Rails.application.config.to_prepare do
#  Hyku.default_bulkrax_field_mappings = ActiveSupport::HashWithIndifferentAccess.new(a: 1)
# end
