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

Blacklight::Document::DublinCore.module_eval do
  # dublin core elements are mapped against the #dublin_core_field_names whitelist.
  def export_as_oai_dc_xml # rubocop:disable Metrics/MethodLength
    xml = Builder::XmlMarkup.new
    xml.tag!("oai_dc:dc",
             'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
             'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
             # 'xmlns:dcterms' => "http://purl.org/dc/terms/",
             # 'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
             'xsi:schemaLocation' => %(http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd)) do
      to_semantic_values.select { |field, _values| dublin_core_field_name? field }.each do |field, values|
        Array.wrap(values).each do |v|
          value_to_tag(v, xml, field)
        end
      end
      to_semantic_values.select { |field, _values| dc_terms_field_name? field }.each do |field, values|
        Array.wrap(values).each do |v|
          value_to_tag(v, xml, field, "dcterms")
        end
      end
    end
    xml.target!
  end
end

# rubocop:disable Metrics/BlockLength
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

  # Add field to the solrDocument (required before nwe fields will appear in catalog controller:w

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

::CatalogController.class_eval do
  blacklight_config.oai[:document][:set_fields] = [
    { label: "Subject Discipline", solr_field: "ethos_subject_sim" },
    { label: "University", solr_field: "current_he_institution_sim" }
  ]

  # I hope there is a better way to re-order facets
  # Remove the ones that are set by hyku
  blacklight_config.facet_fields.delete(:keyword_sim)
  blacklight_config.facet_fields.delete(:subject_sim)
  blacklight_config.facet_fields.delete(:language_sim)

  # Then add all in correct order
  # blacklight_config.add_facet_field 'subject_sim', label: "Subject discipline", limit: 5
  blacklight_config.add_facet_field 'ethos_subject_sim', label: "Subject Discipline", limit: 5 # , single: true
  #  blacklight_config.add_facet_field 'keyword_sim', limit: 5
  blacklight_config.add_facet_field 'date_issued_sim', label: "Date Awarded", limit: 5, sort: 'index' # , single: true
  blacklight_config.add_facet_field 'qualification_name_sim', label: "Qualification Name", limit: 5 # , single: true
  blacklight_config.add_facet_field 'funder_search_sim', label: "Funder(s)", limit: 5
  blacklight_config.add_facet_field 'language_sim', limit: 5
  blacklight_config.add_facet_field 'current_he_institution_sim', label: "University", limit: 5 # , single: true

  blacklight_config.index_fields.delete(:creator_tesim)
  blacklight_config.index_fields.delete(:keyword_tesim)
  blacklight_config.index_fields.delete(:depositor_tesim)
  blacklight_config.index_fields.delete(:contributor_tesim)
  blacklight_config.index_fields.delete(:language_tesim)
  blacklight_config.index_fields.delete(:date_uploaded_dtsi)
  blacklight_config.index_fields.delete(:date_modified_dtsi)
  blacklight_config.index_fields.delete(:license_tesim)

  blacklight_config.add_index_field 'creator_search_tesim', label: "Author", itemprop: 'name', if: :render_in_tenant?
  blacklight_config.add_index_field 'current_he_institution_tesim', label: "University", itemprop: 'name', if: :render_in_tenant?
  blacklight_config.add_index_field 'date_issued_tesim', itemprop: 'date_issued', label: "Date awarded", helper_method: :human_readable_date, if: :render_in_tenant?
  #  blacklight_config.add_index_field 'ethos_identifier_ssi', itemprop: 'ethos_identifier', label: "EThOS ID", if: :render_in_tenant?

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
  blacklight_config.add_show_field 'abstract_tesim', helper_method: :truncate_and_iconify_auto_link
  blacklight_config.add_show_field 'qualification_name_tesim'
  blacklight_config.add_show_field 'qualification_level_tesim'
  blacklight_config.add_show_field 'ethos_institution_tesim'
  blacklight_config.add_show_field 'current_he_institution_tesim'
  blacklight_config.add_show_field 'org_unit_tesim'
  blacklight_config.add_show_field 'funder_tesim'
  blacklight_config.add_show_field 'date_accepted_tesim'
  blacklight_config.add_show_field 'date_issued_tesim'
  blacklight_config.add_show_field 'language_tesim'
  blacklight_config.add_show_field 'keyword_tesim'
  blacklight_config.add_show_field 'ethos_subject_tesim'
  blacklight_config.add_show_field 'dewey_tesim'
  blacklight_config.add_show_field 'ethos_access_rights_tesim'
  blacklight_config.add_show_field 'embargo_date_tesim'
  blacklight_config.add_show_field 'doi_ssim'
  blacklight_config.add_show_field 'ethos_identifier_ssi'
  blacklight_config.add_show_field 'referenced_by_ssim'
  blacklight_config.add_show_field 'oai_identifier_ssim'
  blacklight_config.add_show_field 'licence_tesim'

  blacklight_config.search_fields.delete(:resource_type)

  # This one uses all the defaults set by the solr request handler. Which
  # solr request handler? The one set in config[:default_solr_parameters][:qt],
  # since we aren't specifying it otherwise.
  blacklight_config.search_fields.delete(:all_fields)
  # Re-add the "simple" search fields now we have rejigged all the show fields
  blacklight_config.add_search_field('all_fields', label: 'All Fields', include_in_advanced_search: false) do |field|
    all_names = blacklight_config.show_fields.values.map(&:field).join(" ")
    title_name = 'title_tesim'
    field.solr_parameters = {
      qf: "#{all_names} #{title_name} file_format_tesim all_text_tsimv all_text_tsimv",
      pf: title_name.to_s
    }
  end

  # remove fields from advanced search
  blacklight_config.search_fields = {}

  # Add fields to advanced search (in the order we want)

  blacklight_config.add_search_field('title') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "title"
    }
    solr_name = 'title_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('creator_search', label: 'Author') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "creator_search"
    }
    solr_name = 'creator_search_tesim'
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

  blacklight_config.add_search_field('date_issued', label: "Date Awarded") do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "date_issued"
    }
    solr_name = 'date_issued_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('contributor_search', label: 'Supervisor(s)') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "contributor_search"
    }
    solr_name = 'contributor_search_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('funder_search', label: 'Funder(s)') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "funder_search"
    }
    solr_name = 'funder_search_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('doi') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "doi"
    }
    solr_name = 'doi_ssim referenced_by_ssim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('ethos_identifier') do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "ethos_identifier"
    }
    solr_name = 'ethos_identifier_ssi id'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('dewey', include_in_advanced_search: false) do |field|
    field.solr_parameters = {
      "spellcheck.dictionary": "dewey"
    }
    solr_name = 'dewey_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  blacklight_config.add_search_field('university') do |field|
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
  blacklight_config.view.delete(:gallery)
  blacklight_config.view.delete(:masonry)
  blacklight_config.view.delete(:slideshow)

  blacklight_config.sort_fields.delete('date_created_ssi asc')
  blacklight_config.sort_fields.delete('date_created_ssi desc')
  blacklight_config.sort_fields.delete('system_modified_dtsi asc')
  blacklight_config.sort_fields.delete('system_modified_dtsi desc')

  blacklight_config.add_sort_field "date_issued_sim asc", label: "Date Awarded (Ascending)"
  blacklight_config.add_sort_field "date_issued_sim desc", label: "Date Awarded (Descending)"
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

# Override BlacklightOaiProvider 7.0.2 to handle Dates as well as DateTimes
BlacklightOaiProvider::ResumptionToken.class_eval do
  def encode_conditions
    encoded_token = @prefix.to_s.dup
    encoded_token << ".s(#{set})" if set
    encoded_token << ".f(#{from.to_datetime.utc.xmlschema})" if from
    encoded_token << ".u(#{self.until.to_datetime.utc.xmlschema})" if self.until
    encoded_token << ".t(#{total})" if total
    encoded_token << ":#{last}"
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

# Only show Theses in OAI (no collections)
BlacklightOaiProvider::SolrDocumentWrapper.class_eval do
  def conditions(constraints) # conditions/query derived from options
    query = search_service.search_builder.merge(sort: "#{solr_timestamp} asc", rows: limit).query

    query.append_filter_query("has_model_ssim:ThesisOrDissertation")

    if constraints[:from].present? || constraints[:until].present?
      from_val = solr_date(constraints[:from])
      to_val = solr_date(constraints[:until], true)
      if from_val == to_val
        query.append_filter_query("#{solr_timestamp}:\"#{from_val}\"")
      else
        query.append_filter_query("#{solr_timestamp}:[#{from_val} TO #{to_val}]")
      end
    end

    query.append_filter_query(@set.from_spec(constraints[:set])) if constraints[:set].present?
    query
  end
end

HyraxHelper.module_eval do
  def available_translations
    {
      'en' => 'English'
    }
  end
end

Hyrax::Renderers::AttributeRenderer.class_eval do
  # Draw the dl row for the attribute
  def render_dl_row
    return '' if values.blank? && !options[:include_empty]

    markup = %(<div class="metadata-group"><dt>#{label}</dt>\n<dd><ul class='tabular'>)

    attributes = microdata_object_attributes(field).merge(class: "attribute attribute-#{field}")

    values_array = Array(values)
    values_array.sort! if options[:sort]

    markup += values_array.map do |value|
      "<li#{html_attributes(attributes)}>#{attribute_value_to_html(value.to_s)}</li>"
    end.join
    markup += %(</ul></dd></div>)
    # rubocop:disable Rails/OutputSafety
    markup.html_safe
    # rubocop:enable Rails/OutputSafety
  end
end

# Override Hyrax 5.0.5 add a target to external links
Hyrax::Renderers::ExternalLinkAttributeRenderer.class_eval do
  def li_value(value)
    auto_link(value, html: { target: '_blank', rel: 'noopener external' }) do |link|
      "<span class='fa fa-external-link'></span>&nbsp;#{link}"
    end
  end
end

# Override Hyku override to handle authority labels for facet values (for languages anyway)
Blacklight::FacetsHelperBehavior.class_eval do
  def render_facet_value(facet_field, item, options = {})
    deprecated_method(:render_facet_value)
    facet_config = facet_configuration_for_field(facet_field)
    if facet_field == "language_sim"
      facet_item_component(facet_config, item, facet_field, **options).render_facet_value_with_authority_term
    else
      facet_item_component(facet_config, item, facet_field, **options).render_facet_value
    end
  end

  def render_selected_facet_value(facet_field, item)
    deprecated_method(:render_selected_facet_value)
    facet_config = facet_configuration_for_field(facet_field)
    if facet_field == "language_sim"
      facet_item_component(facet_config, item, facet_field).render_selected_facet_value_with_authority_term
    else
      facet_item_component(facet_config, item, facet_field).render_selected_facet_value
    end
  end
end

# Obvs this will only work for language facet... but that's all we need rn
Blacklight::FacetItemComponent.class_eval do
  def render_facet_value_with_authority_term
    tag.span(class: "facet-label") do
      link_to_unless(@suppress_link, Hyrax::LanguagesService.term(label), href, class: "facet-select", rel: "nofollow")
    end + render_facet_count
  end

  def render_selected_facet_value_with_authority_term
    tag.span(class: "facet-label") do
      tag.span(Hyrax::LanguagesService.term(label), class: "selected") +
        # remove link
        link_to(href, class: "remove", rel: "nofollow") do
          tag.span('✖', class: "remove-icon", aria: { hidden: true }) +
            tag.span(helpers.t(:'blacklight.search.facets.selected.remove'), class: 'sr-only visually-hidden')
        end
    end + render_facet_count(classes: ["selected"])
  end
end

# OVERRIDE HYKU and add a static contact page (used by BL instead of form)
# rubocop:disable Metrics/BlockLength
ContentBlock.class_eval do
  NAME_REGISTRY = {
    marketing: :marketing_text,
    researcher: :featured_researcher,
    announcement: :announcement_text,
    about: :about_page,
    help: :help_page,
    terms: :terms_page,
    agreement: :agreement_page,
    home_text: :home_text,
    homepage_about_section_heading: :homepage_about_section_heading,
    homepage_about_section_content: :homepage_about_section_content,
    contact_us: :contact_us_page
  }.freeze

  # NOTE: method defined outside the metaclass wrapper below because
  # `for` is a reserved word in Ruby.
  def self.for(key)
    key = key.respond_to?(:to_sym) ? key.to_sym : key
    raise ArgumentError, "#{key} is not a ContentBlock name" unless registered?(key)
    ContentBlock.public_send(NAME_REGISTRY[key])
  end

  class << self
    def registered?(key)
      NAME_REGISTRY.include?(key)
    end

    def contact_us_page
      find_or_create_by(name: 'help_page')
    end

    def contact_us_page=(value)
      help_page.update(value:)
    end
  end
end
# rubocop:enable Metrics/BlockLength
