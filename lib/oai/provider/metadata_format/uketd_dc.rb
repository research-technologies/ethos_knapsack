# frozen_string_literal: true
module OAI::Provider::Metadata
  # Simple implementation of the Dublin Core metadata format.
  class UketdDc < Format
    def initialize
      super
      @prefix = 'uketd_dc'
      @schema = 'http://ethos.library.leeds.ac.uk/ethos-oai/2.0/uketd_dc.xsd'
      @namespace = 'http://ethos.library.leeds.ac.uk/uketd/'
      @element_namespace = 'dc'
      @fields = [:title, :creator, :subject, :description, :publisher,
                 :contributor, :date, :type, :format, :identifier,
                 :source, :language, :relation, :coverage, :rights]
    end

    def header_specification
      {
        'xmlns:uketd_dc' => "http://ethos.library.leeds.ac.uk/uketd/",
        'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
        'xmlns:dcterms' => "http://purl.org/dc/terms/",
        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
        'xsi:schemaLocation' =>
          %(http://ethos.library.leeds.ac.uk/uketd/
            http://ethos.library.leeds.ac.uk/ethos-oai/2.0/uketd_dc.xsd
           ).gsub(/\s+/, ' ')
      }
    end
  end
end
