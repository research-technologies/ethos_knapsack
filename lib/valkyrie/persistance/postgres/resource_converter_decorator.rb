# frozen_string_literal: true
# OVERRIDE Valkyrie 3.0.1 to add custom ids
module Valkyrie
  module Persistence
    module Postgres
      module ResourceConverterDecorator
        # Converts the Valkyrie Resource into an ActiveRecord object
        # @return [ORM::Resource]
        def convert!
          return super unless resource.class == ::ThesisOrDissertation
          # Here we make a third choice foor when there is a resource.id but no existing object but we
          # _do_ use that resource id for the new object rather than mint one (this is to catch the historical EThOS IDs)
          # warning: Are we safe from IDs clashing if someone is loose with the Bulkrax input? I don't think
          # so as if ethos_identifer is present but references an existing object...
          # it should pick that up from resource.id for existing items
          # and also if we arrive from the form our ethos_identifier (source_identifier) is nil or a singleton
          # if we arrive from an import our ethos_identifier is in an array and if not passed in has _already_ been sort of minted
          # by the fill_in_blank_source_identifier lamda in the bulkrax config
          ethos_identifier = resource.ethos_identifier.is_a?(Array) ? resource.ethos_identifier.first : resource.ethos_identifier
          current_id = if ethos_identifier.nil?
                         resource.id || ::Ethos::IdentifierService.mint
                       else
                         resource.id || ethos_identifier.gsub("uk.bl.ethos.", "")
                       end
          resource.ethos_identifier = "uk.bl.ethos.#{current_id}" if ethos_identifier.nil?
          orm_class.find_or_initialize_by(id: current_id.to_s).tap do |orm_object|
            orm_object.internal_resource = resource.internal_resource
            process_lock_token(orm_object)
            orm_object.disable_optimistic_locking! unless resource.optimistic_locking_enabled?
            orm_object.metadata = attributes
          end
        end
      end
    end
  end
end

Valkyrie::Persistence::Postgres::ResourceConverter.prepend(Valkyrie::Persistence::Postgres::ResourceConverterDecorator)
