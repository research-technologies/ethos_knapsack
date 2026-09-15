# frozen_string_literal: true

# OVERRIDE Blacklight 7.41.0 to render authority based facet values with the term rather than the id

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

Blacklight::FacetsHelperBehavior.prepend(Blacklight::FacetsHelperBehaviorDecorator)
