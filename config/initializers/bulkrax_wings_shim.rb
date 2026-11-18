# frozen_string_literal: true

# Loads lib/wings/custom_queries/find_by_source_identifier.rb (see its own OVERRIDE
# comment) before hyrax-webapp's config/initializers/wings.rb runs; engine initializers
# run ahead of the main app's own.
require_relative '../../lib/wings/custom_queries/find_by_source_identifier'
