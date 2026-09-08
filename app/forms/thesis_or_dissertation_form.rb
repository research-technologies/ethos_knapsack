# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ThesisOrDissertation`
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see https://github.com/samvera/valkyrie/wiki/ChangeSets-and-Dirty-Tracking
class ThesisOrDissertationForm < Hyrax::Forms::ResourceForm(ThesisOrDissertation)
  #  include Hyrax::FormFields(:basic_metadata)
  include Hyrax::FormFields(:thesis_or_dissertation)
  include HydraEditor::Form::Permissions

  # Define custom form fields using the Valkyrie::ChangeSet interface
  #
  # property :my_custom_form_field

  # if you want a field in the form, but it doesn't have a directly corresponding
  # model attribute, make it virtual

  def self.build_permitted_params
    [:title, :creator]
  end

  #  def self.terms += %i[title alt_title resource_type creator contributor rendering_ids abstract date_published media
  #                     institution org_unit project_name funder fndr_project_ref pagination publisher
  #                     current_he_institution date_accepted date_submitted official_link related_url language license
  #                     rights_statement rights_holder original_doi draft_doi qualification_name qualification_level
  #                     alternate_identifier related_identifier refereed keyword dewey library_of_congress_classification
  #                     add_info rendering_ids ethos_access_rights
  #                    ]

  #    self.required_fields += %i[qualification_name qualification_level]
end
