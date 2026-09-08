# frozen_string_literal: true

# OVERRIDE Blacklight 7.41.0 to render authority based facet values with the term rather than the id

module Blacklight
  module FacetItemComponentDecorator
    def render_facet_value_with_authority_term
      tag.span(class: "facet-label") do
        link_to_unless(@suppress_link, Hyrax::LanguagesService.term(label), href, class: "facet-select", rel: "nofollow")
      end + render_facet_count
    end

    def render_selected_facet_value_with_authority_term
      tag.span(class: "facet-label") do
        tag.span(Hyrax::LanguagesService.term(label), class: "selected") +
          # remove link
          link_to(href, class: "remove", rel: "nofollow") do
            tag.span('✖', class: "remove-icon", aria: { hidden: true }) +
              tag.span(helpers.t(:'blacklight.search.facets.selected.remove'), class: 'sr-only visually-hidden')
          end
      end + render_facet_count(classes: ["selected"])
    end
  end
end

Blacklight::FacetItemComponent.prepend(Blacklight::FacetItemComponentDecorator)
