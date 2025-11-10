# frozen_string_literal: true

# This module provide Dublin Core export based on the document's semantic values
module Blacklight::Document::UketdDc
  def self.extended(document)
    # Register our exportable formats
    Blacklight::Document::UketdDc.register_export_formats(document)
  end

  def self.register_export_formats(document)
    document.will_export_as(:uketd_dc_xml, "text/xml")
  end

  # We can get UKETD XML from a module used by Bulkrax::UketdXmlParser
  def export_as_uketd_dc_xml 
    xml = Bulkrax::UketdXmlRendererBehaviour.dump_xml_partial(self.to_h)
    xml.to_s
  end
end

# Override Blacklight::Document::DublinCore.export_as_oai_dc_xml to take advantage 
# of the new to_semantic_values (as the uketd md profile does) which can handle 
# hashes of fieldnames and produce appropropiate XML tags of the form:
#          <ns:tagname xsi:type="hashkey">hashvalue</ns:tagname>

module Blacklight::Document::DublinCore

  # dublin core elements are mapped against the #dublin_core_field_names whitelist.
  def export_as_oai_dc_xml
    xml = Builder::XmlMarkup.new
    xml.tag!("oai_dc:dc",
             'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
             'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
             'xmlns:dcterms' => "http://purl.org/dc/terms/",
             'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
             'xsi:schemaLocation' => %(http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd)) do

=begin #TODO map the fields and values to DC (see strathclyde for more details)
      self.to_semantic_values.select { |field, _values| dublin_core_field_name? field  }.each do |field, values|
        Array.wrap(values).each do |v|
         value_to_tag(v,xml,field)
        end
      end
      self.to_semantic_values.select { |field, _values| dc_terms_field_name? field  }.each do |field, values|
        Array.wrap(values).each do |v|
         value_to_tag(v,xml,field,"dcterms")
        end
      end
=end
    end
    xml.target!
  end
end
