# frozen_string_literal: true

## Set custom bulkrax parser field mappings for app
parser_mappings = {
      'abstract' => { from: ['abstract'] },
      'ethos_access_rights' => { from: ['accessRights'] },
      'alt_title' => { from: ['alternative'] },
      'contributor_family_name' => { from: ['advisor'], object: 'contributor' },
      'contributor_given_name' => { from: ['advisor'], object: 'contributor' },
      'contributor_role' => { from: ['advisor'], object: 'contributor' },
      'contributor_position' => { from: ['advisor'], object: 'contributor' },
      'creator_family_name' => { from: ['creator'], object: 'creator', skip_object_for_model_names: ['FileSet'] },
      'creator_given_name' => { from: ['creator'], object: 'creator', skip_object_for_model_names: ['FileSet'] },
      'creator_position' => { from: ['creator'], object: 'creator', skip_object_for_model_names: ['FileSet'] },
      'creator_isni' => { from: ['authoridentifier_isni'], object: 'creator', skip_object_for_model_names: ['FileSet'] }, # type="uketdterms:ISNI"
      'creator_orcid' => { from: ['authoridentifier_orcid'], object: 'creator', skip_object_for_model_names: ['FileSet'] }, # type="uketdterms:ORCID"
      'current_he_institution' => { from: ['institution'] },
      'date_accepted' => { from: ['issued'] },
      'dewey' => { from: ['subject'] }, # type="dcterms:Ddc"
      'doi' => { from: ['identifier'] }, # type="dcterms:DOI"
      'embargo_date' => { from: ['embargodate'] },
      # 'embargo_date' => { from: ['dcterms:accessRights'] },
      'funder_award' => { from: ['ugrantnumber'], object: "funder", split: /\s*;\s*/ },
      'funder_name' => { from: ['sponsor'], object: "funder" },
      'source_record' => { from: ['source'], source_identifier: true }, #we would like to map this to source_record and for that to also be the bulkrax identifier maybe?
      'keyword' => { from: ['coverage'], split: /\s*;\s*/ },
      'language' => { from: ['language'] }, # type="dcterms:ISO639-2"
      'org_unit' => { from: ['department'] },
      'official_link' => { from: ['isReferencedBy'] },
      'publisher' => { from: ['publisher'] },
      'qualification_name' => { from: ['type'] },
      'qualification_level' => { from: ['qualificationlevel'] },
      'title' => { from: ['title'] },
      'parents' => { from: ['parents'], split: /\s*[;|]\s*/, related_parents_field_mapping: true },
      'children' => { from: ['children'], split: /\s*[;|]\s*/, related_children_field_mapping: true },
      'alternate_identifier' => { from: %w[provenance source relation], object: 'alternate_identifier' },
      'alternate_identifier_type' => { from: %w[provenance source relation], object: 'alternate_identifier' },
#      'original_identifier' => { from: ['source'] }
      #OAI identifier' => dcterms:provenance
      #EThOS identifier' => dc:source
      #Aleph system number => dc:relation
    }


# currently Bulkrax does not support headers with spaces
# here we add the key but with the underscore turned into a space to accommodate
parser_mappings.each do |key, value|
  value[:from] += ([key.tr('_', ' ')] + value[:from].map { |f| f.tr('_', ' ') })
  value[:from].uniq!
end

# all parsers use the same mappings:
mappings = {}
#mappings["Bulkrax::BagitParser"] = parser_mappings
mappings["Bulkrax::XmlEtdDcParser"] = parser_mappings
Hyku.default_bulkrax_field_mappings = mappings
