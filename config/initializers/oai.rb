# frozen_string_literal: true

# Load the uketd_dc OAI provider
require 'oai/provider/metadata_format/uketd_dc'
OAI::Provider::Base.register_format(OAI::Provider::Metadata::UketdDc.instance)
# rubocop:disable Metrics/BlockLength
Rails.application.config.after_initialize do
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

  Blacklight::Document::DublinCore.module_eval do # rubocop:disable Metrics/BlockLength
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
            value_to_tag(translate_authority(v, field), xml, field)
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

    def translate_authority(v, field)
      if field == :publisher
        Hyrax::CurrentHeInstitutionsService.label(v)
      else
        v
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
