# frozen_string_literal: true

# Load the uketd_dc OAI provider
require 'oai/provider/metadata_format/uketd_dc'
OAI::Provider::Base.register_format(OAI::Provider::Metadata::UketdDc.instance)
# rubocop:disable Metrics/BlockLength
Rails.application.config.after_initialize do
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
        dini_oai_elements.each { |field, value| value_to_tag(value, xml, field) }
      end
      xml.target!
    end

    def translate_authority(v, field)
      case field
      when :publisher then Hyrax::CurrentHeInstitutionsService.label(v)
      when :language then Ethos::Dini.iso_639_3(v)
      else v
      end
    end

    # Values DINI requires in oai_dc only, so uketd_dc is left as it is.
    def dini_oai_elements
      levels = self['qualification_level_tesim']
      types = Ethos::Dini.doc_types(levels).map { |type| "doc-type:#{type}" } + Ethos::Dini.coar_types(levels)
      subjects = Ethos::Dini.ddc_groups(self['dewey_tesim']).map { |group| "ddc:#{group}" }

      types.map { |value| [:type, value] } + subjects.map { |value| [:subject, value] }
    end
  end
end
# rubocop:enable Metrics/BlockLength
