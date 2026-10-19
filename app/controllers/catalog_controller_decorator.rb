# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
module CatalogControllerDecorator

end

CatalogController.prepend(CatalogControllerDecorator)

CatalogController.configure_blacklight do |config|

  config.oai[:document][:set_fields] = [
    { label: "Subject Discipline", solr_field: "ethos_subject_sim" },
    { label: "University", solr_field: "current_he_institution_sim", helper_method: :current_he_institution_label }
  ]

  # I hope there is a better way to re-order facets
  # Remove the ones that are set by hyku
  config.facet_fields.clear
  # Then add all in correct order
  config.add_facet_field 'subject_sim', label: "Subject discipline", limit: 5
  config.add_facet_field 'ethos_subject_sim', label: "Subject Discipline", limit: 5 # , single: true
  config.add_facet_field 'keyword_sim', limit: 5
  config.add_facet_field 'date_issued_sim', label: "Date Awarded", limit: 5, sort: 'index' # , single: true
  config.add_facet_field 'qualification_name_sim', label: "Qualification Name", limit: 5 # , single: true
  config.add_facet_field 'funder_search_sim', label: "Funder(s)", limit: 5
  config.add_facet_field 'language_sim', limit: 5
  config.add_facet_field 'current_he_institution_sim', label: "University", limit: 5, helper_method: :current_he_institution_label # , single: true

  config.index_fields.clear
  config.add_index_field 'title_tesim', label: "Title", itemprop: 'name', if: :render_in_tenant?
  config.add_index_field 'creator_search_tesim', label: "Author", itemprop: 'name', if: :render_in_tenant?
  config.add_index_field 'current_he_institution_tesim', label: "University", itemprop: 'name', if: :render_in_tenant?, helper_method: :current_he_institution_label
  config.add_index_field 'date_issued_tesim', itemprop: 'date_issued', label: "Date awarded", helper_method: :human_readable_date, if: :render_in_tenant?
  #  config.add_index_field 'ethos_identifier_ssi', itemprop: 'ethos_identifier', label: "EThOS ID", if: :render_in_tenant?
  #
  # solr fields to be displayed in the show (single result) view
  # The ordering of the field names is the order of the display

  config.show_fields.clear
  config.add_show_field 'title_tesim'
  config.add_show_field 'alternative_title_tesim'
  config.add_show_field 'creator_tesim'
  config.add_show_field 'contributor_tesim'
  config.add_show_field 'abstract_tesim', helper_method: :truncate_and_iconify_auto_link
  config.add_show_field 'qualification_name_tesim'
  config.add_show_field 'qualification_level_tesim'
  config.add_show_field 'ethos_institution_tesim'
  config.add_show_field 'current_he_institution_tesim'
  config.add_show_field 'org_unit_tesim'
  config.add_show_field 'funder_tesim'
  config.add_show_field 'date_accepted_tesim'
  config.add_show_field 'date_issued_tesim'
  config.add_show_field 'language_tesim'
  config.add_show_field 'keyword_tesim'
  config.add_show_field 'ethos_subject_tesim'
  config.add_show_field 'dewey_tesim'
  config.add_show_field 'ethos_access_rights_tesim'
  config.add_show_field 'embargo_date_tesim'
  config.add_show_field 'doi_ssim'
  config.add_show_field 'ethos_identifier_ssi'
  config.add_show_field 'referenced_by_ssim'
  config.add_show_field 'oai_identifier_ssim'
  config.add_show_field 'licence_tesim'

  config.search_fields.delete(:resource_type)
 
  # This one uses all the defaults set by the solr request handler. Which
  # solr request handler? The one set in config[:default_solr_parameters][:qt],
  # since we aren't specifying it otherwise.
  config.search_fields.delete(:all_fields)
  # Re-add the "simple" search fields now we have rejigged all the show fields
  config.add_search_field('all_fields', label: 'All Fields', include_in_advanced_search: false) do |field|
    all_names = config.show_fields.values.map(&:field).join(" ")
    title_name = 'title_tesim'
    field.solr_parameters = {
      qf: "#{all_names} #{title_name} file_format_tesim all_text_tsimv all_text_tsimv",
      pf: title_name.to_s
    }
  end

  # remove fields from advanced search
  config.search_fields = {}

  # Add fields to advanced search (in the order we want)

  config.add_search_field('title') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "title"
    }
    solr_name = 'title_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('creator_search', label: 'Author') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "creator_search"
    }
    solr_name = 'creator_search_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('abstract') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "abstract"
    }
    solr_name = 'abstract_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('date_issued', label: "Date Awarded") do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "date_issued"
    }
    solr_name = 'date_issued_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('contributor_search', label: 'Supervisor(s)') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "contributor_search"
    }
    solr_name = 'contributor_search_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('funder_search', label: 'Funder(s)') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "funder_search"
    }
    solr_name = 'funder_search_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('doi') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "doi"
    }
    solr_name = 'doi_ssim referenced_by_ssim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('ethos_identifier') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "ethos_identifier"
    }
    solr_name = 'ethos_identifier_ssi id'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('dewey', include_in_advanced_search: false) do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "dewey"
    }
    solr_name = 'dewey_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.add_search_field('university') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "current_he_institution"
    }
    solr_name = 'current_he_institution_tesim ethos_institution_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  # supress blacklight view options while we are largely text based
  config.view.delete(:gallery)
  config.view.delete(:masonry)
  config.view.delete(:slideshow)

  config.sort_fields.clear
  config.add_sort_field "date_issued_sim asc", label: "Date Awarded (Ascending)"
  config.add_sort_field "date_issued_sim desc", label: "Date Awarded (Descending)"
end

