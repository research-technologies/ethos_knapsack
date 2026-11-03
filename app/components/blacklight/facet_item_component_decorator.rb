# frozen_string_literal: true

# OVERRIDE Blacklight 7.41 to show the language term, not its id, in the language facet.
# Decorate the component's label rather than the render_facet_* helpers: overriding
# those sends Blacklight down its legacy path, which fails for nested components such
# as Hyrax::DropdownFacetFieldComponent.
module Blacklight
  module FacetItemComponentDecorator
    LANGUAGE_FACET = 'language_sim'

    def label
      return super unless @facet_item.facet_field.to_s == LANGUAGE_FACET

      Hyrax::LanguagesService.term(super).presence || super
    end
  end
end

Blacklight::FacetItemComponent.prepend(Blacklight::FacetItemComponentDecorator)
