# frozen_string_literal: true

require 'nokogiri'
module Bulkrax
  # Custom XML Entry for British Library's Electronic Theses and Dissertations.
  class XmlEtdDcEntry < XmlEntry # rubocop:disable Metrics/ClassLength
    serialize :raw_metadata, JSON

    def factory_class
      ThesisOrDissertation
    end

    def self.record_has_source_identifier(data, source_id, parser, index)
      xpath_for_source_id = ".//*[name()='#{source_id}']"
      identifier = data.xpath(xpath_for_source_id)&.first&.text
      if identifier.blank?
        if Bulkrax.fill_in_blank_source_identifiers.present?
          identifier = Bulkrax.fill_in_blank_source_identifiers.call(parser, index)
        else
          invalid_record("Missing #{source_identifier} for #{record.to_h}\n")
          return false
        end
      end
      identifier
    end

    def self.data_for_entry(data, source_id, parser, index = 1)
      collections = []
      children = []
      identifier = record_has_source_identifier(data, source_id, parser, index)
      {
        source_id => identifier,
        delete: data.xpath(".//*[name()='delete']").first&.text,
        data:
          data.to_xml(
            encoding: 'UTF-8',
            save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS
          ).delete("\n").delete("\t").squeeze(' '), # Remove newlines, tabs, and extra whitespace
        collection: collections,
        children:
      }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_metadata
      raise StandardError, 'Record not found' if record.nil?
      raise StandardError, "Missing source identifier (#{source_identifier})" if raw_metadata[source_identifier].blank?
      self.parsed_metadata = {}
      parsed_metadata[work_identifier] = [raw_metadata[source_identifier]]
      field_mapping_from_values_for_xml_element_names.each do |element_name|
        # TODO: Refactor this so we don't have duplicate loops and multiple places that repeat
        #       knowledge (e.g. what's the field name, or how we loop over elements)
        next if complicated_elements.include?(element_name)
        elements = record.xpath("//*[name()='#{element_name}']")
        next if elements.blank?
        elements.each do |el|
          delete_metadata(element_name) if el.children.blank?
          el.children.each do |child|
            content = child.content
            add_metadata(element_name, content) if content.present?
          end
        end
      end
      add_additional
      # parsed_metadata['file'] = raw_metadata['file']

      add_local
      validate_oai_identifier
      parsed_metadata
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength#

    def add_additional
      add_model
      add_complicated_fields
      add_visibility
      add_rights_statement
      add_admin_set_id
      add_collections
    end

    def validate_oai_identifier
      return unless (existing_record = existing_record_by_oai_identifier?)
      raise StandardError, "There is an existing record with the same oai_identifier #{parsed_metadata['oai_identifier']} : #{existing_record}"
    end

    def existing_record_by_oai_identifier?
      return nil if parsed_metadata['oai_identifier'].blank?
      match = Hyrax.query_service.custom_query.find_by_property_value(property: 'oai_identifier', value: parsed_metadata['oai_identifier'], search_field: 'oai_identifier_ssi')
      return nil if match && match.ethos_identifier == parsed_metadata['ethos_identifier'] # dont' match yourself mate
      match
    end

    def add_model
      parsed_metadata['model'] = 'ThesisOrDissertation'
    end

    def complicated_elements
      %w[authoridentifier_isni authoridentifier_orcid subject identifier language advisor creator] # maybe embargo_date
    end

    def add_complicated_fields
      add_authoridentifier
      add_dewey
      add_subject
      add_doi
      add_other_identifier
      add_language
      add_creator
      add_advisor

      # alt identifier
    end

    # @todo consider how we might put this "configuration logic" in the parser where it's a bit more visible
    def add_authoridentifier
      add_complicated_element('authoridentifier_isni', 'authoridentifier', 'uketdterms:ISNI')
      add_complicated_element('authoridentifier_orcid', 'authoridentifier', 'uketdterms:ORCID')
    end

    # @todo consider how we might put this "configuration logic" in the parser where it's a bit more visible
    def add_dewey
      add_one_to_many_element('dewey', 'subject', 'dcterms:DDC')
    end

    def add_subject
      add_one_to_many_element('keyword', 'subject', nil)
    end

    # @todo consider how we might put this "configuration logic" in the parser where it's a bit more visible
    def add_doi
      add_one_to_many_element('doi', 'identifier', 'dcterms:DOI')
    end

    def add_other_identifier
      add_one_to_many_element('other_identifier', 'identifier', 'dcterms:URI')
    end

    def add_language
      add_complicated_element('language', 'language', 'dcterms:ISO639-2')
    end

    def add_complicated_element(element_label, element_name, type_value)
      elements = record.xpath("//*[name()='#{element_name}']")
      return if elements.blank?
      elements.each do |el|
        delete_metadata(element_label) if el.children.blank? && el.attr('type') == type_value
        el.children.each do |child|
          content = child.content
          add_metadata(element_label, content) if content.present? && el.attr('type') == type_value
        end
      end
    end

    # This is very similar to adding a complicated element, but here we set the parsed_metadata directly which will
    # allow us to do things like setting two ditinct hyrax fields from multiple instances of the same element
    # that have different attributes
    # rubocop:disable Metrics/AbcSize
    def add_one_to_many_element(element_label, element_name, type_value)
      elements = record.xpath("//*[name()='#{element_name}']")
      return if elements.blank?
      elements.each do |el|
        delete_metadata(element_label) if el.children.blank? && el.attr('type') == type_value
        el.children.each do |child|
          content = child.content
          content = content.split(Regexp.new(importerexporter.field_mapping[element_label]['split'])) if importerexporter.field_mapping[element_label].key?('split')
          parsed_metadata[element_label] = [] unless parsed_metadata.key? element_label
          parsed_metadata[element_label] << content if content.present? && el.attr('type') == type_value
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    def add_creator
      add_name_field('creator', 'creator')
    end

    def add_advisor
      add_name_field('contributor', 'advisor', type: 'Supervisor')
    end

    # @param type [String] This value must match as an element in the ContributorGroupService's
    #        authority.
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def add_name_field(name_field_prefix, element_name, type: nil)
      elements = record.xpath("//*[name()='#{element_name}']")
      return if elements.blank?
      position = 0
      elements.each do |el|
        el.children.each do |child|
          content = child.content
          names = content.split(/\s*;\s*/)
          next if names.blank?
          names.each do |name|
            separated_name = name.split(/\s*,\s*/)
            next if separated_name.blank?
            # @todo consier using https://rubygems.org/gems/namae for name parsing
            add_metadata("#{name_field_prefix}_family_name", (separated_name.first || ''), position)
            add_metadata("#{name_field_prefix}_given_name", (separated_name.length > 1 ? separated_name.last : ''), position)
            add_metadata("#{name_field_prefix}_position", position, position)
            if type
              #      guard_type!(type)
              add_metadata("#{name_field_prefix}_role", type, position)
            end
            position += 1
          end
        end
      end
    end

    def delete_metadata(node_name)
      # Here we delete the data from tags that are present but empty!
      # TODO work out what to do for multiple fields.... one <dc:subject></dc:subject> means we delete a keyword, but which one!
      # Workaround == we know when we are dealing with multiples and we use the fact that we will parse
      # ; delimited lists to present modified lists
      fields = field_to(node_name)
      fields.each do |field|
        parsed_metadata[field] = nil
      end

      # More TODO we also need to check attributes... as <dc:subject xsi:type="DDC"/> means remove a dewey
    end

    # @return [TrueClass] when the given type is valid
    # @raise [RuntimeError] when the given type is not valid
    #
    # @see ./app/views/shared/ubiquity/contributor/_edit_array_hash_form.html.erb The UI element
    #      that shows what is the range of values for the contributor_type field.
    def guard_type!(type)
      return true if ContributorGroupService.new.authority.find(type).present?

      raise "Expected type: #{type.inspect} to be present in ContributorGroupService authority."
    end

    # Methods to effect a UKETD XML _export_

    def build_export_metadata
      self.parsed_metadata = {}

      build_system_metadata
      #      build_files_metadata if Bulkrax.collection_model_class.present? && !hyrax_record.is_a?(Bulkrax.collection_model_class)
      build_relationship_metadata
      build_mapping_metadata
      save!

      parsed_metadata
    end

    # Metadata required by Bulkrax for round-tripping
    def build_system_metadata
      parsed_metadata['id'] = hyrax_record.id
      parsed_metadata[key_for_export('visibility')] = hyrax_record.visibility
      source_id = hyrax_record.send(work_identifier)
      # Because ActiveTriples::Relation does not respond to #to_ary we can't rely on Array.wrap universally
      source_id = source_id.to_a if source_id.is_a?(ActiveTriples::Relation)
      source_id = Array.wrap(source_id).first
      parsed_metadata[source_identifier] = source_id
      model_name = Bulkrax.object_factory.model_name(resource: hyrax_record)
      parsed_metadata[key_for_export('model')] = model_name
    end

    #    def build_files_metadata
    #      # attaching files to the FileSet row only so we don't have duplicates when importing to a new tenant
    #      if hyrax_record.work?
    #        build_thumbnail_files
    #      else
    #        file_mapping = key_for_export('file')
    #        file_sets = hyrax_record.file_set? ? Array.wrap(hyrax_record) : hyrax_record.file_sets
    #        filenames = map_file_sets(file_sets)
    #
    #        handle_join_on_export(file_mapping, filenames, mapping['file']&.[]('join')&.present?)
    #      end
    #    end

    def build_relationship_metadata
      # Includes all relationship methods for all exportable record types (works, Collections, FileSets)
      relationship_methods = {
        related_parents_parsed_mapping => %i[member_of_collection_ids member_of_work_ids in_work_ids parent],
        related_children_parsed_mapping => %i[member_collection_ids member_work_ids file_set_ids member_ids]
      }

      relationship_methods.each do |relationship_key, methods|
        next if relationship_key.blank?
        values = []
        methods.each do |m|
          value = hyrax_record.public_send(m) if hyrax_record.respond_to?(m)
          value_id = value.try(:id)&.to_s || value # get the id if it's an object
          values << value_id if value_id.present?
        end
        values = values.flatten.uniq
        next if values.blank?
        handle_join_on_export(relationship_key, values, mapping[related_parents_parsed_mapping]['join'].present?)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # The purpose of this helper module is to make easier the testing of the rather complex
    # switching logic for determining the method we use for building the value.
    module AttributeBuilderMethod
      # @param key [Symbol]
      # @param value [Hash<String, Object>]
      # @param entry [Bulkrax::Entry]
      #
      # @return [NilClass] when we won't be processing this field
      # @return [Symbol] (either :build_value or :build_object)
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def self.for(key:, value:, entry:)
        return if key == 'model'
        return if key == 'file'
        return if key == entry.related_parents_parsed_mapping
        return if key == entry.related_children_parsed_mapping
        return if value['excluded'] || value[:excluded]
        return if Bulkrax.reserved_properties.include?(key) && !entry.field_supported?(key)

        object_key = key if value.key?('object') || value.key?(:object)
        return unless entry.hyrax_record.respond_to?(key.to_s) || object_key.present?

        models_to_skip = Array.wrap(value['skip_object_for_model_names'] || value[:skip_object_for_model_names] || [])

        return :build_value if models_to_skip.detect { |model| entry.factory_class.model_name.name == model }
        return :build_object if object_key.present?

        :build_value
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    end

    def build_mapping_metadata
      mapping = fetch_field_mapping
      mapping.each do |key, value|
        method_name = AttributeBuilderMethod.for(key:, value:, entry: self)
        next unless method_name

        send(method_name, key, value)
      end
    end

    def build_object(key, value)
      return unless hyrax_record.respond_to?(value['object'])

      data = hyrax_record.send(value['object'])
      return if data.empty?

      data = data.to_a if data.is_a?(ActiveTriples::Relation)
      object_metadata(key, Array.wrap(data))
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_value(property_name, mapping_config)
      return unless hyrax_record.respond_to?(property_name.to_s)
      data = hyrax_record.send(property_name.to_s)
      if mapping_config['join'] || !data.is_a?(Enumerable)
        if many_to_one_elements.include?(property_name.to_s)
          parsed_metadata["#{key_for_export(property_name)}_#{property_name}"] = prepare_export_data_with_join(data)
        else
          parsed_metadata[key_for_export(property_name)] = prepare_export_data_with_join(data)
        end
      else
        data.each_with_index do |d, i|
          if many_to_one_elements.include?(property_name.to_s) # not sure this will ever get tickled
            parsed_metadata["#{key_for_export(property_name)}_#{property_name}_#{i + 1}"] = prepare_export_data(d)
          else
            parsed_metadata["#{key_for_export(property_name)}_#{i + 1}"] = prepare_export_data(d)
          end
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def many_to_one_elements
      %w[doi other_identifier dewey keyword] # maybe embargo_date
    end

    # On export the key becomes the from and the from becomes the destination. It is the opposite of the import because we are moving data the opposite direction
    # metadata that does not have a specific Bulkrax entry is mapped to the key name, as matching keys coming in are mapped by the parser automatically
    def key_for_export(key)
      clean_key = key_without_numbers(key)
      unnumbered_key = mapping[clean_key] ? mapping[clean_key]['from'].first : clean_key
      # Bring the number back if there is one
      "#{unnumbered_key}#{key.sub(clean_key, '')}"
    end

    def prepare_export_data_with_join(data)
      # Yes...it's possible we're asking to coerce a multi-value but only have a single value.
      return data.to_s unless data.is_a?(Enumerable)
      return "" if data.empty?

      data.map { |d| prepare_export_data(d) }.join(Bulkrax.multi_value_element_join_on).to_s
    end

    def prepare_export_data_keep_as_array(data)
      # Yes...it's possible we're asking to coerce a multi-value but only have a single value.
      return data.to_s unless data.is_a?(Enumerable)
      return "" if data.empty?
      data.map { |d| prepare_export_data(d) }
    end

    def prepare_export_data(datum)
      if datum.is_a?(ActiveTriples::Resource)
        datum.to_uri.to_s
      else
        datum
      end
    end

    def object_metadata(key, data)
      data = data.map { |d| eval(d) }.flatten # rubocop:disable Security/Eval
      parsed_metadata[key_for_export(key).to_s] = send("map_#{key_for_export(key)}", data)
    end

    def map_creator(data)
      data.map { |d| { 'creator_family_name' => d['creator_family_name'], 'creator_given_name' => d['creator_given_name'] } }
    end

    def map_authoridentifier_isni(data)
      data.map { |d| d['creator_isni'] }
    end

    def map_authoridentifier_orcid(data)
      data.map { |d| d['creator_orcid'] }
    end

    def map_advisor(data)
      data.map { |d| { 'contributor_family_name' => d['contributor_family_name'], 'contributor_given_name' => d['contributor_given_name'] } }
    end

    def map_sponsor(data)
      data.map { |d| d['funder_name'] }
    end

    def map_grantnumber(data)
      data.map { |d| d['funder_award'] }.reject { |fa| fa.blank? || fa.first.nil? }.flatten
    end
  end
end
