# frozen_string_literal: true

Rails.application.config.after_initialize do 
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
  
    # Override and offer translation of an authority id into a term if possible
    def name
      (field, value) = spec.split(':')
      if field == "University"
        "#{field.titleize}: #{Hyrax::CurrentHeInstitutionsService.label(value)}"
      else
        spec.titleize.gsub(':', ': ')
      end
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
      FAQs: :help_page,
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
        find_or_create_by(name: 'contact_us_page')
      end
  
      def contact_us_page=(value)
        contact_us_page.update(value:)
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
