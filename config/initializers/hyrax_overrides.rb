# frozen_string_literal: true

#OVERIDE various bits of Hyrax with 'orrible monkey patches, TODO make these decorators

# rubocop:enable Metrics/BlockLength

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
  
end
# rubocop:enable Metrics/BlockLength
