# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ThesisOrDissertation`
class ThesisOrDissertation < Hyrax::Work
  #  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:thesis_or_dissertation)
  #  include Hyrax::Schema(:with_pdf_viewer)
  #  include Hyrax::Schema(:with_video_embed)
  include Hyrax::ArResource
  include Hyrax::NestedWorks

  #  include IiifPrint.model_configuration(
  #    pdf_split_child_model: GenericWorkResource,
  #    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  #  )

  prepend OrderAlready.for(:creator)
  def assign_id
    super
  end

  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:creator_search_tesim] = resource.creator.map { |c| c.values.join(', ') }
  #    end
  #  end
end
