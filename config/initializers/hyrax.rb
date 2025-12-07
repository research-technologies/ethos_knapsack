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

# rubocop:disable Metrics/BlockLength
SolrDocument.class_eval do
  use_extension(Blacklight::Document::UketdDc)
  def to_uketd_dc
    export_as('uketd_dc_xml')
  end

  # Add field to the solrDocument (required before nwe fields will appear in catalog controller:w

  attribute :alternative_title, Hyrax::SolrDocument::Metadata::Solr::Array, 'alternative_title_tesim'
  attribute :creator, Hyrax::SolrDocument::Metadata::Solr::Array, 'creator_tesim'
  attribute :contributor, Hyrax::SolrDocument::Metadata::Solr::Array, 'contributor_tesim'
  attribute :abstract, Hyrax::SolrDocument::Metadata::Solr::Array, 'abstract_tesim'
  attribute :qualification_name, Hyrax::SolrDocument::Metadata::Solr::Array, 'qualification_name_tesim'
  attribute :qualification_level, Hyrax::SolrDocument::Metadata::Solr::Array, 'qualification_level_tesim'
  attribute :institution, Hyrax::SolrDocument::Metadata::Solr::Array, 'institution_tesim'
  attribute :current_he_institution, Hyrax::SolrDocument::Metadata::Solr::Array, 'current_he_institution_tesim'
  attribute :org_unit, Hyrax::SolrDocument::Metadata::Solr::Array, 'org_unit_tesim'
  attribute :sponsor, Hyrax::SolrDocument::Metadata::Solr::Array, 'sponsor_tesim'
  attribute :date_accepted, Hyrax::SolrDocument::Metadata::Solr::Array, 'date_accepted_tesim'
  attribute :date_issued, Hyrax::SolrDocument::Metadata::Solr::Array, 'date_issued_tesim'
  attribute :language, Hyrax::SolrDocument::Metadata::Solr::Array, 'language_tesim'
  attribute :keyword, Hyrax::SolrDocument::Metadata::Solr::Array, 'keyword_tesim'
  attribute :ethos_subject, Hyrax::SolrDocument::Metadata::Solr::Array, 'ethos_subject_tesim'
  attribute :dewey, Hyrax::SolrDocument::Metadata::Solr::Array, 'dewey_tesim'
  attribute :ethos_access_rights, Hyrax::SolrDocument::Metadata::Solr::Array, 'ethos_access_rights_tesim'
  attribute :embargo_date, Hyrax::SolrDocument::Metadata::Solr::Array, 'embargo_date_ssim'
  attribute :doi, Hyrax::SolrDocument::Metadata::Solr::Array, 'doi_ssim'
  attribute :referenced_by, Hyrax::SolrDocument::Metadata::Solr::Array, 'referenced_by_ssim'
  attribute :oai_identifier, Hyrax::SolrDocument::Metadata::Solr::Array, 'oai_identifier_ssim'
  attribute :licence, Hyrax::SolrDocument::Metadata::Solr::Array, 'licence_tesim'
end

::CatalogController.class_eval do
  blacklight_config.oai[:document][:set_fields] = [
    { label: "Subject Discipline", solr_field: "ethos_subject_sim" },
    #    { label: "Full Text", solr_field: "referenced_by_ssi" },
    { label: "Institution", solr_field: "current_he_institution_sim" }
  ]

  # I hope there is a better way to re-order facets
  # Remove the ones that are set by hyku
  blacklight_config.facet_fields.delete(:keyword_sim)
  blacklight_config.facet_fields.delete(:subject_sim)
  blacklight_config.facet_fields.delete(:language_sim)

  # Then add all in correct order
  # blacklight_config.add_facet_field 'subject_sim', label: "Subject discipline", limit: 5
  blacklight_config.add_facet_field 'ethos_subject_sim', label: "Subject Discipline", limit: 5
  blacklight_config.add_facet_field 'keyword_sim', limit: 5
  blacklight_config.add_facet_field 'date_issued_sim', label: "Date Awarded", limit: 5, sort: 'index'
  blacklight_config.add_facet_field 'qualification_name_sim', label: "Qualification Name", limit: 5
  blacklight_config.add_facet_field 'funder_sim', label: "Funder / Sponsor", limit: 5
  blacklight_config.add_facet_field 'language_sim', limit: 5
  blacklight_config.add_facet_field 'current_he_institution_sim', label: "University", limit: 5

  # solr fields to be displayed in the show (single result) view
  # The ordering of the field names is the order of the display

  blacklight_config.show_fields.delete(:alternative_title_tesim)
  blacklight_config.show_fields.delete(:creator_tesim)
  blacklight_config.show_fields.delete(:contributor_tesim)
  blacklight_config.show_fields.delete(:abstract_tesim)
  blacklight_config.show_fields.delete(:language_tesim)
  blacklight_config.show_fields.delete(:keyword_tesim)

  blacklight_config.add_show_field 'alternative_title_tesim'
  blacklight_config.add_show_field 'creator_tesim'
  blacklight_config.add_show_field 'contributor_tesim'
  blacklight_config.add_show_field 'abstract_tesim'
  blacklight_config.add_show_field 'qualification_name_tesim'
  blacklight_config.add_show_field 'qualification_level_tesim'
  blacklight_config.add_show_field 'institution_tesim'
  blacklight_config.add_show_field 'current_he_institution_tesim'
  blacklight_config.add_show_field 'org_unit_tesim'
  blacklight_config.add_show_field 'sponsor_tesim'
  blacklight_config.add_show_field 'date_accepted_tesim'
  blacklight_config.add_show_field 'date_issued_tesim'
  blacklight_config.add_show_field 'language_tesim'
  blacklight_config.add_show_field 'keyword_tesim'
  blacklight_config.add_show_field 'ethos_subject_tesim'
  blacklight_config.add_show_field 'dewey_tesim'
  blacklight_config.add_show_field 'ethos_access_rights_tesim'
  blacklight_config.add_show_field 'embargo_date_tesim'
  blacklight_config.add_show_field 'doi_ssim'
  blacklight_config.add_show_field 'referenced_by_ssim'
  blacklight_config.add_show_field 'oai_identifier_ssim'
  blacklight_config.add_show_field 'licence_tesim'

  # This one uses all the defaults set by the solr request handler. Which
  # solr request handler? The one set in config[:default_solr_parameters][:qt],
  # since we aren't specifying it otherwise.
  blacklight_config.search_fields.delete(:all_fields)
  # Re-add the "simple" search fields now we have rejigged all the show fields
  blacklight_config.add_search_field('all_fields', label: 'All Fields', include_in_advanced_search: false) do |field|
    all_names = blacklight_config.show_fields.values.map(&:field).join(" ")
    title_name = 'title_tesim'
    field.solr_parameters = {
      qf: "#{all_names} #{title_name} id file_format_tesim all_text_tsimv all_text_tsimv",
      pf: title_name.to_s
    }
  end

  # Adavnaced search fields

  blacklight_config.add_search_field('doi') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "doi"
    }
    solr_name = 'doi_ssim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('abstract') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "abstract"
    }
    solr_name = 'abstract_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('qualification_name') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "qualification_name"
    }
    solr_name = 'qualification_name_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end
end
# rubocop:enable Metrics/BlockLength

# Overrides Hyku WorkShowPresenter
Hyku::WorkShowPresenter.class_eval do
  def doi
    doi_regex = %r{10\.\d{4,9}\/[-._;()\/:A-Z0-9]+}i
    doi = extract_from_identifier(doi_regex)
    doi&.join
  end

  def extract_from_identifier(rgx)
    if solr_document['doi_ssim'].present?
      ref = solr_document['doi_ssim'].map do |str|
        str.scan(rgx)
      end
    end
    ref
  end
end

# Overrides blacklight_oai_provider
BlacklightOaiProvider::SolrSet.class_eval do
  def self.sets_from_facets(facet_results)
    sets = Array.wrap(@fields).map do |f|
      facet_results.fetch(f[:solr_field], [])
                   .each_slice(2)
                   .select { |t| t[0] != '' } # added to avoid choking on empty values
                   .map { |t| new("#{f[:label]}:#{t.first}") }
    end.flatten

    sets.empty? ? nil : sets
  end
end

HyraxHelper.module_eval do
  def available_translations
    {
      'en' => 'English'
    }
  end
end
