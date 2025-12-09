require 'nokogiri'

xml_file = 'data/EThOS_FullLoadFile_251208.xml'
puts "Reading the big XML"
po = Nokogiri::XML::ParseOptions.new.huge.strict
doc = Nokogiri::XML(open(xml_file),nil,'UTF-8',po).remove_namespaces!
puts "Read that now we loop..."

xml = <<~EOF
        <oai_dc:dcCollection xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc">
          </foo:parent>
        </oai_dc:dcCollection>
      EOF
new_doc = Nokogiri::XML(xml)

chunk = 10_000
limit = 100_000
file_name = chunk.dup
dir_name = "data_#{chunk}"
FileUtils.mkdir_p dir_name
doc.xpath("/dcCollection/uketddc").each_with_index do | uketd, index |
  rec = uketd.clone
  new_doc.root << rec
  if (index+1) % chunk == 0
    File.open(File.join(dir_name,"#{file_name}.xml"), 'w') {|f| f.write(new_doc.to_s) }
    file_name = file_name+chunk
    new_doc = Nokogiri::XML(xml)
  end
  break if (index+1) == limit
end
