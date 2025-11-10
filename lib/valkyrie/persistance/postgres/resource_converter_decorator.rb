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
          current_id = if resource.ethos_identifier.nil?
                         resource.id || ::Ethos::IdentifierService.mint
                       else
                         resource.id || resource.ethos_identifier.gsub("uk.bl.ethos.", "")
                       end
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
