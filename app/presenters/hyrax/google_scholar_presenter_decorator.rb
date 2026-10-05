# frozen_string_literal: true

## OVERRIDE Hyrav 5.0.2 to map thesis date_issued to publication_date for gscholar
module Hyrax
  module GoogleScholarPresenterDecorator

    # @return [Array<String>] an ordered array of author names
    def authors
      return object.ordered_authors if object.respond_to?(:ordered_authors)
      Array(object.creator.map{|c| cc=eval(c) ; "#{cc['creator_family_name']}, #{cc['creator_given_name']}"}) 
    end

    # @return [String] the publication date
    def publication_date
      Array(object.try(:date_issued)).first || ''
    end 
  end
end

Hyrax::GoogleScholarPresenter.prepend(Hyrax::GoogleScholarPresenterDecorator)
