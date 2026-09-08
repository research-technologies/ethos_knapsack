# frozen_string_literal: true

module HykuKnapsack
  module ApplicationHelper
    def current_he_institution_label(field)
      if field.is_a? Hash
        value = field[:document][field[:field]]
        value = nil if value.present? && value.all?(&:blank?)
      else
        value = field
      end
      ::Hyrax::CurrentHeInstitutionsService.label(value) if value.present?
    end
  end
end
