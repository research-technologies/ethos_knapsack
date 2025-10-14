# frozen_string_literal: true

## Set custom bulkrax parser field mappings for app
parser_mappings = {
  'title' => { from: ['title'] },
  'alt_title' => { from: ['alternative'] },
  'creator_family_name' => { from: ['creator'], object: 'creator', skip_object_for_model_names: ['FileSet'] },
  'creator_given_name' => { from: ['creator'], object: 'creator', skip_object_for_model_names: ['FileSet'] },
  'creator_position' => { from: ['creator'], object: 'creator', skip_object_for_model_names: ['FileSet'] },
  'creator_isni' => { from: ['authoridentifier_isni'], object: 'creator', skip_object_for_model_names: ['FileSet'] }, # type="uketdterms:ISNI"
  'creator_orcid' => { from: ['authoridentifier_orcid'], object: 'creator', skip_object_for_model_names: ['FileSet'] }, # type="uketdterms:ORCID"
  'contributor_family_name' => { from: ['advisor'], object: 'contributor' },
  'contributor_given_name' => { from: ['advisor'], object: 'contributor' },
  'contributor_role' => { from: ['advisor'], object: 'contributor' },
  'contributor_position' => { from: ['advisor'], object: 'contributor' },
  'abstract' => { from: ['abstract'] },
  'qualification_name' => { from: ['type'] },
  'qualification_level' => { from: ['qualificationlevel'] },
  'institution' => { from: ['publisher'] },
  'current_he_institution' => { from: ['institution'] },
  'org_unit' => { from: ['department'] },
  'funder_name' => { from: ['sponsor'], object: "funder" },
  'funder_award' => { from: ['grantnumber'], object: "funder", split: /\s*;\s*/ },
  'date_issued' => { from: ['issued'] },
  'language' => { from: ['language'] }, # type="dcterms:ISO639-2"
  'keyword' => { from: ['coverage'], split: /\s*;\s*/ },
  'dewey' => { from: ['subject'] }, # type="dcterms:DDC"
  'subject' => { from: ['subject'] },
  'ethos_access_rights' => { from: ['accessRights'] },
  'embargo_date' => { from: ['embargodate'] },
  'ethos_identifier' => { from: ['source'] },
  'doi' => { from: ['identifier'] }, # type="dcterms:DOI"
  'referenced_by' => { from: ['isReferencedBy'] },
  'oai_identifier' => { from: ['provenance'] },
  'bl_cat_identifier' => { from: ['relation'] },
  'alternate_identifier' => { from: ['identifier'] }, # type="dcterms:URI"
  'source_record' => { from: ['source'], source_identifier: true },
  'parents' => { from: ['parents'], split: /\s*[;|]\s*/, related_parents_field_mapping: true },
  'children' => { from: ['children'], split: /\s*[;|]\s*/, related_children_field_mapping: true }
}

# currently Bulkrax does not support headers with spaces
# here we add the key but with the underscore turned into a space to accommodate
parser_mappings.each do |key, value|
  value[:from] += ([key.tr('_', ' ')] + value[:from].map { |f| f.tr('_', ' ') })
  value[:from].uniq!
end

# all parsers use the same mappings:
mappings = {}
# mappings["Bulkrax::BagitParser"] = parser_mappings
mappings["Bulkrax::XmlEtdDcParser"] = parser_mappings
Hyku.default_bulkrax_field_mappings = mappings
