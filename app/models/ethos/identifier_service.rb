# frozen_string_literal: true

module Ethos
  # Absolutely insistent on sequential numeric IDs, these are inherently risky,
  # but they won't listen...
  #
  # NOTE: The module should be included AFTER the Hyrax::WorkBehavior module
  # is included, because this module overrides the #assign_id method that
  # comes from including Hyrax::WorkBehavior.
  module IdentifierService
    # mint
    # Mints a new ID for use in Fedora/Postgres/Solr that is a sequential number
    # We use Rails cache to store the last one created and we increment after we access it
    # This number will only go up, it won't revert or decrease should a) the object not
    # end up getting created or b) the object is deleted... In some small way, we have
    # just made Hyrax into EPrints :/
    # @return [String] a new ID
    def self.mint
      loop do
        new_id = Rails.cache.fetch("thesis_id") { 1 }
        Rails.cache.write("thesis_id", (new_id + 1))
        break if usable_id? new_id
      end
      new_id.to_s
    end

    def self.usable_id?(id)
      return false unless id
      !!!ActiveFedora::SolrService.query("id:#{id}", rows: 1).first
    end
  end
end
