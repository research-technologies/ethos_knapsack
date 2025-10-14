# frozen_string_literal: true

module Bulkrax::HasLocalProcessing
  # This method is called during build_metadata
  # add any special processing here, for example to reset a metadata property
  # to add a custom property from outside of the import data
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def add_local
#    parsed_metadata['resource_type'] = ['ThesisOrDissertation Doctoral thesis'] if parser.is_a? Bulkrax::XmlEtdDcParser
#    parsed_metadata['creator_search'] = parsed_metadata&.[]('creator_search')&.map { |c| c.values.join(', ') }
    parsed_metadata["qualification_name"] = set_qualification_name if parsed_metadata["qualification_name"]
    parsed_metadata['record_level_file_version_declaration'] = ActiveModel::Type::Boolean.new.cast parsed_metadata['record_level_file_version_declaration']
    set_institutional_relationships

    debugger
    parsed_metadata['ethos_identifier'] = Rack::Utils.parse_query(URI(parsed_metadata['source_record']).query)['uin']
    compound_fields = {
      'creator' => ['family_name', 'given_name', 'orcid', 'isni'],
      'contributor' => ['role', 'family_name', 'given_name'],
    }

    # split funder awards on ; todo possibly funder_names too!
    parsed_metadata['funder']&.each do | funder |
      funder['funder_award'] = funder['funder_award'].blank? ? [] : funder['funder_award'].split(';')
    end

    compound_fields.each do |field, sub_fields|
      sub_fields.each do |sub_field|
        field_name = "#{field}_#{sub_field}"
        next if parsed_metadata[field].blank?
        parsed_metadata[field].each_with_index do |sub_values|
          parsed_metadata[field_name] ||= []
          parsed_metadata[field_name] << sub_values[field_name]
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def set_qualification_name
    if parsed_metadata['qualification_name'].gsub(/\s+/, "").downcase.tr('.', '').include?('phd')
      'PhD'
    else
      parsed_metadata['qualification_name']
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def set_institutional_relationships
    acceptable_values = {
      'researchassociate': 'Research associate',
      'staffmember': 'Staff member',
      'doctoralcollaborativestudent': 'Doctoral collaborative student'
    }

    # remove the invalid keys in the array below and use the `<object>_institional_relationship` key only
    ['contributor_researchassociate', 'contributor_staffmember', 'creator_researchassociate', 'creator_staffmember', 'editor_researchassociate', 'editor_staffmember'].each do |field|
      object, relationship = field.split('_')
      key = "#{object}_institutional_relationship"
      next if parsed_metadata[object].blank?
      parsed_metadata[object].each_with_index do |obj, index|
        next unless parsed_metadata&.[](object)&.[](index)
        # skip if no object or no object at index
        # if object and index are preset, but key is either nil or empty AND obj[field] is present, set the key
        if obj[field].present?
          if parsed_metadata[object][index][key]&.first.blank?
            parsed_metadata[object][index][key] = [acceptable_values[relationship.to_sym]]
          else
            parsed_metadata[object][index][key] << acceptable_values[relationship.to_sym]
          end
        end

        parsed_metadata&.[](object)&.[](index)&.delete(field)
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
