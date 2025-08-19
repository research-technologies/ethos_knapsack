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

  # Not sure what _should_ go in here, but this seems harmless and if this is not overridden here, it carps 
  def self.build_permitted_params
    [:title, :creator]
  end 

end
