# frozen_string_literal: true

module Bulkrax
  class XmlEtdDcParser < XmlParser
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

    def collections; end


#    def create_works
#      results = self.records(quick: true)
#      return if results.blank?
#      results.full.each_with_index do |record, index|
#        identifier = record_has_source_identifier(record, index)
#        next unless identifier
#        break if limit_reached?(limit, index)
#
#        seen[identifier] = true
#        create_entry_and_job(record, 'work', identifier)
#        increment_counters(index, work: true)
#      end
#      importer.record_status
#    rescue StandardError => e
#      set_status_info(e)
#    end

  end
end
