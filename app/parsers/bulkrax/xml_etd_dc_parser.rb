# frozen_string_literal: true

module Bulkrax
  class XmlEtdDcParser < XmlParser # rubocop:disable Metrics/ClassLength
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
      1000
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

        group.each do |entry|
          uketddc_node = XML::Node.new('uketddc')
          uketd_dc_namespaces.each do |ns, ns_url|
            add_namespace(uketddc_node, ns.to_s, ns_url)
          end
          uketddc_node['xsi:schemaLocation'] = "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/uketd_dc.xsd"
          doc.root << uketddc_node
          entry.parsed_metadata.each do |key, value|
            unnumbered_key = key.gsub(/_\d+$/, '')
            next unless uketd_tags.key?(unnumbered_key.to_sym)
            render(unnumbered_key, value, uketddc_node)
          end
        end
        doc.save(setup_export_file(folder_count), indent: true, encoding: XML::Encoding::UTF_8)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def render(key, value, uketddc_node)
      send("render_#{key}", key, value, uketddc_node)
    rescue NoMethodError
      uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", value)
    end

    def render_creator(key, value, uketddc_node)
      value.each do |v|
        uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", "#{v['creator_family_name']}, #{v['creator_given_name']}")
      end
    end

    def render_advisor(key, value, uketddc_node)
      value.each do |v|
        uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", "#{v['contributor_family_name']}, #{v['contributor_given_name']}")
      end
    end

    def render_sponsor(key, value, uketddc_node)
      uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", value.join(' ; '))
    end

    def render_grantnumber(key, value, uketddc_node)
      value.each do |v|
        uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", v)
      end
    end

    def render_language(key, value, uketddc_node)
      language_node = XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", value)
      XML::Attr.new(language_node, "xsi:type", "dcterms:ISO639-2")
      uketddc_node << language_node
    end

    def render_identifier_doi(_key, value, uketddc_node)
      identifier_node = XML::Node.new("#{uketd_tags['identifier_doi'.to_sym]}:identifier", value)
      XML::Attr.new(identifier_node, "xsi:type", "dcterms:DOI")
      uketddc_node << identifier_node
    end

    def render_identifier_other_identifier(_key, value, uketddc_node)
      identifier_node = XML::Node.new("#{uketd_tags['identifier_other_identifier'.to_sym]}:identifier", value)
      XML::Attr.new(identifier_node, "xsi:type", "dcterms:URI")
      uketddc_node << identifier_node
    end

    def render_authoridentifier_isni(_key, value, uketddc_node)
      value.each do |v|
        identifier_node = XML::Node.new("#{uketd_tags['authoridentifier_isni'.to_sym]}:authoridentifier", v)
        XML::Attr.new(identifier_node, "xsi:type", "uketdterms:ISNI")
        uketddc_node << identifier_node
      end
    end

    def render_authoridentifier_orcid(_key, value, uketddc_node)
      value.each do |v|
        identifier_node = XML::Node.new("#{uketd_tags['authoridentifier_orcid'.to_sym]}:authoridentifier", v)
        XML::Attr.new(identifier_node, "xsi:type", "uketdterms:ORCID")
        uketddc_node << identifier_node
      end
    end

    def render_subject_ethos_subject(_key, value, uketddc_node)
      uketddc_node << XML::Node.new("#{uketd_tags['subject_ethos_subject'.to_sym]}:subject", value)
    end

    def render_subject_dewey(_key, value, uketddc_node)
      subject_node = XML::Node.new("#{uketd_tags['subject_dewey'.to_sym]}:subject", value)
      XML::Attr.new(subject_node, "xsi:type", "dcterms:DDC")
      uketddc_node << subject_node
    end

    # rubocop:disable Metrics/MethodLength
    def uketd_tags
      {
        relation: 'dc',
        title: 'dc',
        creator: 'dc',
        authoridentifier_isni: 'uketdterms', # xsi:type="uketdterms:ISNI"
        authoridentifier_orcid: 'uketdterms', # xsi:type="uketdterms:ORCID"
        advisor: 'uketdterms',
        institution: 'uketdterms',
        department: 'uketdterms',
        publisher: 'dc',
        issued: 'dcterms',
        abstract: 'dcterms',
        alternative: 'dcterms',
        subject_dewey: 'dc', # xsi:type="dcterms:DDC"
        subject_ethos_subject: 'dc',
        coverage: 'dc',
        type: 'dc',
        qualificationlevel: 'uketdterms',
        embargodate: 'uketdterms',
        sponsor: 'uketdterms',
        grantnumber: 'uketdterms',
        language: 'dc', # xsi:type="dcterms:ISO639-2"
        isReferencedBy: 'dcterms',
        identifier_doi: 'dc', # xsi:type="dcterms:DOI"
        identifier_other_identifier: 'dc', # xsi:type="dcterms:URI"
        provenance: 'dcterms',
        source: 'dc',
        accessRights: 'dcterms'
      }
    end
    # rubocop:enable Metrics/MethodLength

    def uketd_dc_namespaces
      {
        oai_dc: "http://www.openarchives.org/OAI/2.0/oai_dc/",
        xsi: "http://www.w3.org/2001/XMLSchema-instance",
        dc: "http://purl.org/dc/elements/1.1/",
        dcterms: "http://purl.org/dc/terms/",
        uketdterms: "http://naca.central.cranfield.ac.uk/ethos-oai/terms/",
        uketd_dc: "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/"
      }
    end

    def add_namespace(node, ns, ns_url)
      node.namespaces.namespace = XML::Namespace.new(node, ns, ns_url)
    end

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
