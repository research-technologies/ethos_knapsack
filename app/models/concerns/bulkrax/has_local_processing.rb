# frozen_string_literal: true

module Bulkrax::HasLocalProcessing
  # This method is called during build_metadata
  # add any special processing here, for example to reset a metadata property
  # to add a custom property from outside of the import data
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def add_local
    parsed_metadata["qualification_name"] = set_qualification_name if parsed_metadata["qualification_name"]
    parsed_metadata["qualification_level"] = set_qualification_level
    parsed_metadata["ethos_access_rights"] = set_ethos_access_rights if parsed_metadata["ethos_access_rights"]

    compound_fields = {
      'creator' => ['family_name', 'given_name', 'orcid', 'isni'],
      'contributor' => ['role', 'family_name', 'given_name']
    }
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
    set_funder
  end

  def set_funder
    funders = []
    grants = []
    # split funder awards on ; oh no... funder_names too!
    return nil unless parsed_metadata.key?('funder')
    funders = if parsed_metadata['funder'].first['funder_name']&.include?(' ; ')
                parsed_metadata['funder'].first['funder_name'].split(' ; ')
              else
                [parsed_metadata['funder']&.first&.[]('funder_name')]
              end

    grants = if parsed_metadata['funder'].first['funder_award']&.include?(' ; ')
               parsed_metadata['funder'].first['funder_award'].split(' ; ')
             else
               [parsed_metadata['funder']&.first&.[]('funder_award')]
             end

    # leave funder unchanged if not present

    parsed_metadata['funder'] = []
    funders.each_with_index do |funder, index|
      parsed_metadata['funder'] = [] if parsed_metadata['funder'].blank?
      funder_obj = { 'funder_name' => funder, 'funder_award' => [] }
      if index == (funders.count - 1) # we have no more funders so you get all the grants
        funder_obj['funder_award'] = grants if grants.present?
      elsif grants.present?
        funder_obj['funder_award'] << grants.shift
      end
      parsed_metadata['funder'] << funder_obj
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def set_qualification_name
    parsed_metadata['qualification_name'].gsub(/^\s*Thesis\s*/, "").tr('().', '')
  end

  def set_ethos_access_rights
    parsed_metadata['ethos_access_rights'].downcase
  end

  def set_qualification_level
    "Doctoral"
  end

end
