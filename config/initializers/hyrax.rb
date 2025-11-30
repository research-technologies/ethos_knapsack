# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    # Injected via `rails g hyrax:work_resource ThesisOrDissertation`
    config.register_curation_concern :thesis_or_dissertation
    config.enable_noids = false
  end
end

# Register authorities
Qa::Authorities::Local.register_subauthority('qualification_names', 'Qa::Authorities::Local::FileBasedAuthority')
Qa::Authorities::Local.register_subauthority('qualification_levels', 'Qa::Authorities::Local::FileBasedAuthority')
Qa::Authorities::Local.register_subauthority('languages', 'Qa::Authorities::Local::FileBasedAuthority')
Qa::Authorities::Local.register_subauthority('current_he_institutions', 'Qa::Authorities::Local::FileBasedAuthority')
Qa::Authorities::Local.register_subauthority('contributor_roles', 'Qa::Authorities::Local::FileBasedAuthority')

# Load the uketd_dc OAI provider
require 'oai/provider/metadata_format/uketd_dc'
OAI::Provider::Base.register_format(OAI::Provider::Metadata::UketdDc.instance)

SolrDocument.class_eval do
  use_extension(Blacklight::Document::UketdDc)
  def to_uketd_dc
    export_as('uketd_dc_xml')
  end
end

::CatalogController.class_eval do
  blacklight_config.oai[:document][:set_fields] = [
#    { label: "Subject Discipline", solr_field: "subject_sim" },
#    { label: "Full Text", solr_field: "referenced_by_ssi" },
    { label: "Institution", solr_field: "current_he_institution_sim" }
  ]

  # I hope there is a better way to re-order facets
  # Remove the ones that are set by hyku
  blacklight_config.facet_fields.delete(:keyword_sim)
  blacklight_config.facet_fields.delete(:subject_sim)
  blacklight_config.facet_fields.delete(:language_sim)
  # Then add all in correct order
  blacklight_config.add_facet_field 'subject_sim', label: "Subject discipline", limit: 5
  blacklight_config.add_facet_field 'keyword_sim', limit: 5
  blacklight_config.add_facet_field 'date_issued_sim', label: "Date Awarded", limit: 5
  blacklight_config.add_facet_field 'qualification_name_sim', label: "Qualification Name", limit: 5
  blacklight_config.add_facet_field 'funder_sim', label: "Funder / Sponsor", limit: 5
  blacklight_config.add_facet_field 'language_sim', limit: 5
  blacklight_config.add_facet_field 'current_he_institution_sim', label: "University", limit: 5

  # blacklight_config.add_facet_field 'dewey_sim', label: "Dewey", limit: 5
  # blacklight_config.add_facet_field 'ethos_institution_sim', label: "Institution", limit: 5
end

HyraxHelper.module_eval do
  def available_translations
    {
      'en' => 'English'
    }
  end
end
