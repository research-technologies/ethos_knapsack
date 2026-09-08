# frozen_string_literal: true

module Bulkrax
  class XmlEtdDcParser < XmlParser # rubocop:disable Metrics/ClassLength
    include UketdXmlRendererBehaviour

    def self.export_supported?
      true
    end

    def entry_class
      Bulkrax::XmlEtdDcEntry
    end

    def create_relationships
      ScheduleRelationshipsJob.set(wait: 5.minutes).perform_later(importer_id: importerexporter.id)
    end

    def file_set_entry_class; end

    def create_file_sets; end

    def file_sets; end

    def collection_entry_class; end

    def create_collections
      STDERR.puts "In uketd create_collections (what does nothing)"
    end

    # For multiple, we expect to find metadata for multiple works in the given metadata file(s)
    # For single, we expect to find metadata for a single work in the given metadata file(s)
    #  if the file contains more than one record, we take only the first
    # In either case there may be multiple metadata files returned by metadata_paths
    def records(_opts = {})
      @records ||=
        if parser_fields['import_type'] == 'multiple'
          r = []
          metadata_paths.map.with_index do |md, index|
            # Retrieve all records
            elements = entry_class.read_data(md).xpath("//#{record_element}")
            r += elements.map { |el| entry_class.data_for_entry(el, source_identifier, self, index) }
          end
          # Flatten because we may have multiple records per array
          r.compact.flatten
        elsif parser_fields['import_type'] == 'single'
          metadata_paths.map do |md|
            data = entry_class.read_data(md).xpath("//#{record_element}").first # Take only the first record
            entry_class.data_for_entry(data, source_identifier, self)
          end.compact # No need to flatten because we take only the first record
        end
    end

    def current_records_for_export
      @current_records_for_export ||= Bulkrax::ParserExportRecordSet.for(
        parser: self,
        export_from: importerexporter.export_from
      )
    end

    def total
      @total =
        if importer?
          records.size
        elsif exporter?
          limit.to_i.zero? ? current_records_for_export.count : limit.to_i
        else
          0
        end

      @total
    rescue StandardError
      @total = 0
    end

    def records_split_count
      1_000_000
    end

    def create_new_entries
      # NOTE: The each method enforces the limit, as it can best optimize the underlying queries.
      current_records_for_export.each do |id, entry_class|
        new_entry = find_or_create_entry(entry_class, id, 'Bulkrax::Exporter')
        begin
          entry = ExportWorkJob.perform_now(new_entry.id, current_run.id)
        rescue => e
          Rails.logger.info("#{e.message} was detected during export")
        end

        self.headers |= entry.parsed_metadata.keys if entry
      end
    end
    alias create_from_collection create_new_entries
    alias create_from_importer create_new_entries
    alias create_from_worktype create_new_entries
    alias create_from_all create_new_entries

    def collections; end

    def valid_entry_types
      [entry_class.to_s]
    end

    # export methods
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def write_files
      require 'open-uri'
      folder_count = 0
      # TODO: This is not performant as well; unclear how to address, but lower priority as of
      #       <2023-02-21 Tue>.
      sorted_entries = sort_entries(importerexporter.entries.uniq(&:identifier))
                       .select { |e| valid_entry_types.include?(e.type) }

      require 'xml'

      group_size = limit.to_i.zero? ? total : limit.to_i
      sorted_entries[0..group_size].in_groups_of(records_split_count, false) do |group|
        folder_count += 1

        doc = XML::Document.string('<oai_dc:dcCollection xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc"/>')
        renderer = Bulkrax::UketdXmlRendererBehaviour
        group.each do |entry|
          uketddc_node = XML::Node.new('uketddc')
          renderer.uketd_dc_namespaces.each do |ns, ns_url|
            renderer.add_namespace(uketddc_node, ns.to_s, ns_url)
          end
          uketddc_node['xsi:schemaLocation'] = "https://ethos.library.leeds.ac.uk/ethos-oai/2.0/uketddc.xsd"
          doc.root << uketddc_node
          subjects = []
          entry.parsed_metadata.each do |key, value|
            unnumbered_key = key.gsub(/_\d+$/, '')
            next unless renderer.uketd_tags.key?(unnumbered_key.to_sym)
            if unnumbered_key == 'subject_keyword'
              subjects << value
              next
            end
            renderer.render(unnumbered_key, value, uketddc_node)
          end
          renderer.render("type", "Thesis or Dissertation", uketddc_node)
          renderer.render("subject_keyword", subjects, uketddc_node)
        end
        doc.save(setup_export_file(folder_count), indent: true, encoding: XML::Encoding::UTF_8)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # in the parser as it is specific to the format
    def setup_export_file(folder_count)
      path = File.join(importerexporter.exporter_export_path, folder_count.to_s)
      FileUtils.mkdir_p(path) unless File.exist?(path)

      File.join(path, "export_#{importerexporter.export_source}_from_#{importerexporter.export_from}_#{folder_count}.xml")
    end

    def sort_entries(entries)
      # always export models in the same order: work, collection, file set
      #
      # TODO: This is a problem in that only these classes are compared.  Instead
      #       We should add a comparison operator to the classes.
      entries.sort_by do |entry|
        case entry.type
        when 'Bulkrax::XmlEtdCollectionEntry'
          '1'
        when 'Bulkrax::XmlEtdFileSetEntry'
          '2'
        else
          '0'
        end
      end
    end
  end
end
