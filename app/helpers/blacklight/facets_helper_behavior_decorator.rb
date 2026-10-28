# frozen_string_literal: true

module Blacklight
  module FacetsHelperBehaviorDecorator
    def render_facet_value(facet_field, item, options = {})
      deprecated_method(:render_facet_value)
      facet_config = facet_configuration_for_field(facet_field)
      if facet_field == "language_sim"
        facet_item_component(facet_config, item, facet_field, **options).render_facet_value_with_authority_term
      else
        facet_item_component(facet_config, item, facet_field, **options).render_facet_value
      end
    end

    def render_selected_facet_value(facet_field, item)
      deprecated_method(:render_selected_facet_value)
      facet_config = facet_configuration_for_field(facet_field)
      if facet_field == "language_sim"
        facet_item_component(facet_config, item, facet_field).render_selected_facet_value_with_authority_term
      else
        facet_item_component(facet_config, item, facet_field).render_selected_facet_value
      end
    end
  end
end

module Blacklight
  module FacetItemComponentDecorator
    # Obvs this will only work for language facet... but that's all we need rn
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

Blacklight::FacetsHelperBehavior.prepend(Blacklight::FacetsHelperBehaviorDecorator)
Blacklight::FacetItemComponent.prepend(Blacklight::FacetItemComponentDecorator)
