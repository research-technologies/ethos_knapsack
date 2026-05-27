# frozen_string_literal: true

# Override blacklight-7.35.0 until we update hyku to include https://github.com/samvera/hyku/pull/3020
module Blacklight
  class StartOverButtonComponent < Blacklight::Component
    def call
      link_to t('blacklight.search.ethos_start_over'), start_over_path, class: 'catalog_startOverLink btn btn-primary'
    end

    private

    ##
    # Get the path to the search action with any parameters (e.g. view type)
    # that should be persisted across search sessions.
    def start_over_path(query_params = params)
      Deprecation.silence(Blacklight::UrlHelperBehavior) do
        helpers.start_over_path(query_params)
      end
    end
  end
end
