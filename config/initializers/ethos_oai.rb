# frozen_string_literal: true

# Load the uketd_dc OAI provider
require 'oai/provider/metadata_format/uketd_dc'
OAI::Provider::Base.register_format(OAI::Provider::Metadata::UketdDc.instance)

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
