# frozen_string_literal: true

# Use this to override any Bulkrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Bulkrax.setup do |config|
    config.parsers += [
      { name: " XML - UKETD DC Parser", class_name: "Bulkrax::XmlEtdDcParser", partial: "xml_fields" }
    ]

    #    config.fill_in_blank_source_identifiers = ->(obj, index) { "#{Site.instance.account.name}-#{obj.importerexporter.id}-#{index}" }
    config.fill_in_blank_source_identifiers = ->(_obj, _index) { "uk.bl.ethos.#{::Ethos::IdentifierService.mint}" }
  end
  Bulkrax::Importer::DEFAULT_OBJECT_TYPES = ['work'].freeze
end

Bulkrax::ObjectFactoryInterface.base_permitted_attributes += [:creator_family_name, :creator_given_name, :creator_isni, :creator_orcid, :contributor_role, :contributor_family_name,
                                                              :contributor_given_name, :funder_name, :funder_award]

# Override bulkrax (9.1.0 4bb4426) we don't want to be found by id, this is so we can add legacy ids in
Bulkrax::ObjectFactoryInterface.class_eval do
  def find
    search_by_identifier || nil
  end
end

# Override bulkrax (9.1.0 4bb4426) We only want to force title and creator to '' if we are not updating
# This will allow partial XML updates to not clobber title and creator
Bulkrax::ValkyrieObjectFactory.class_eval do
  def transform_attributes(update: false) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    attrs = super.merge(alternate_ids: [source_identifier_value])
                 .symbolize_keys

    unless update
      missing_fields = []
      # required fields removed for initial load of legacy data
      # :oai_identifier, :qualification_name, :qualification_level
      required_fields = [:title, :creator, :current_he_institution, :date_issued, :language]
      required_fields.each do |required_field|
        missing_fields << required_field if attrs[required_field].blank?
      end
      raise StandardError, "The following required fields are absent: #{missing_fields.map(&:to_s).join(', ')}" if missing_fields.count.positive?
    end
    unless attrs[:current_he_institution].blank? || Hyrax::CurrentHeInstitutionsService.select_active_options_id.include?(attrs[:current_he_institution])
      raise StandardError, "The Current Institution value was not found in the authority file (#{attrs[:current_he_institution]})"
    end
    #    unless attrs[:qualification_name].blank? || Hyrax::QualificationNamesService.select_all_option_just_ids.include?(attrs[:qualification_name])
    #      raise StandardError, "The Qualification Name value was not found in the authority file (#{attrs[:qualification_name]})"
    #    end
    attrs
  end
end
