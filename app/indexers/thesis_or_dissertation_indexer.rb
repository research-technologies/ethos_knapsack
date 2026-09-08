# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ThesisOrDissertation`
class ThesisOrDissertationIndexer < Hyrax::ValkyrieWorkIndexer
  #  include Hyrax::Indexer(:basic_metadata)
  include Hyrax::Indexer(:thesis_or_dissertation)
  include HykuIndexing

  # Uncomment this block if you want to add custom indexing behavior:
  def to_solr
    super.tap do |index_document|
      index_document[:title_tesim]   = resource.title
      #index_document[:other_field_ssim] = resource.other_field
    end
  end
end
