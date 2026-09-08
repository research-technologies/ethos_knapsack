# frozen_string_literal: true

# OVERRIDE HYKU 7.1 make a solrDocument for EThOS

# rubocop:disable Metrics/BlockLength
Rails.application.config.after_initialize do
  SolrDocument.class_eval do
    use_extension(Hydra::ContentNegotiation)
    field_semantics.merge!(
      contributor: 'contributor_tesim',
      creator: 'creator_tesim',
      date: 'date_issued_tesim',
      description: 'abstract_tesim',
      identifier: ['doi_ssim', 'id'],
      language: 'language_tesim',
      publisher: 'current_he_institution_tesim',
      source: 'referenced_by_ssim',
      subject: ['dewey_tesim', 'keyword_tesim'],
      title: 'title_tesim'
    )

    use_extension(Blacklight::Document::UketdDc)
    def to_uketd_dc
      export_as('uketd_dc_xml')
    end

    # Add field to the solrDocument (required before new fields will appear in catalog controller)

    attribute :title, Hyrax::SolrDocument::Metadata::Solr::Array, 'title_tesim'
    attribute :alternative_title, Hyrax::SolrDocument::Metadata::Solr::Array, 'alternative_title_tesim'
    attribute :creator, Hyrax::SolrDocument::Metadata::Solr::Array, 'creator_tesim'
    attribute :creator_search, Hyrax::SolrDocument::Metadata::Solr::Array, 'creator_search_tesim'
    attribute :contributor, Hyrax::SolrDocument::Metadata::Solr::Array, 'contributor_tesim'
    attribute :contributor_search, Hyrax::SolrDocument::Metadata::Solr::Array, 'contributor_search_tesim'
    attribute :abstract, Hyrax::SolrDocument::Metadata::Solr::Array, 'abstract_tesim'
    attribute :qualification_name, Hyrax::SolrDocument::Metadata::Solr::Array, 'qualification_name_tesim'
    attribute :qualification_level, Hyrax::SolrDocument::Metadata::Solr::Array, 'qualification_level_tesim'
    attribute :ethos_institution, Hyrax::SolrDocument::Metadata::Solr::Array, 'ethos_institution_tesim'
    attribute :current_he_institution, Hyrax::SolrDocument::Metadata::Solr::Array, 'current_he_institution_tesim'
    attribute :org_unit, Hyrax::SolrDocument::Metadata::Solr::Array, 'org_unit_tesim'
    attribute :funder, Hyrax::SolrDocument::Metadata::Solr::Array, 'funder_tesim'
    attribute :funder_search, Hyrax::SolrDocument::Metadata::Solr::Array, 'funder_search_tesim'
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
    attribute :ethos_identifier, Hyrax::SolrDocument::Metadata::Solr::Array, 'ethos_identifier_tesim'
    attribute :ethos_identifier, Hyrax::SolrDocument::Metadata::Solr::Array, 'ethos_identifier_ssi'
    attribute :licence, Hyrax::SolrDocument::Metadata::Solr::Array, 'licence_tesim'
  end
end
# rubocop:enable Metrics/BlockLength
