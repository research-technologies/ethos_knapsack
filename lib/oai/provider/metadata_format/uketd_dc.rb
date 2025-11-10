module OAI::Provider::Metadata

  # Simple implementation of the Dublin Core metadata format.
  class UketdDc < Format

#  <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

# <uketd_dc:uketddc xmlns:uketd_dc="http://naca.central.cranfield.ac.uk/ethos-oai/2.0/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:uketdterms="http://naca.central.cranfield.ac.uk/ethos-oai/terms/" xsi:schemaLocation="http://naca.central.cranfield.ac.uk/ethos-oai/2.0/ http://naca.central.cranfield.ac.uk/ethos-oai/2.0/uketd_dc.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    def initialize
      @prefix = 'uketd_dc'
      @schema = 'http://naca.central.cranfield.ac.uk/ethos-oai/2.0/uketd_dc.xsd'
      @namespace = 'http://naca.central.cranfield.ac.uk/ethos-oai/2.0/'
      @element_namespace = 'dc'
      @fields = [ :title, :creator, :subject, :description, :publisher,
                  :contributor, :date, :type, :format, :identifier,
                  :source, :language, :relation, :coverage, :rights]
    end

    def header_specification
      {
        'xmlns:uketd_dc' => "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/",
        'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
        'xmlns:dcterms' => "http://purl.org/dc/terms/",
        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
        'xsi:schemaLocation' =>
          %{http://naca.central.cranfield.ac.uk/ethos-oai/2.0/ 
            http://naca.central.cranfield.ac.uk/ethos-oai/2.0/uketd_dc.xsd
           }.gsub(/\s+/, ' ')
      }
    end

  end
end
