# frozen_string_literal: true

# OVERRIDE Hyrax v5.0.5 to add constraints to escape `.` characters in id params

module ActionDispatch
  module Routing
    module MapperDecorator
      def curation_concerns_basic_routes
        scope constraints: { id: /[^\/]+/ } do
          super

          namespace :hyrax, path: :concern do
            additional_hyrax_concern_routes
          end
        end
      end

      private

      # add any other routes under /concern/<resource>/:id where :id needs to be constrained
      def additional_hyrax_concern_routes
        resources :permissions, only: [] do
          member do
            get :confirm
            post :copy
            get :confirm_access
            post :copy_access
          end
        end

        # Example of adding routes for another resource
        # resources :other_resource, only: [] do
        #   member do
        #     get :some_action
        #   end
        # end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.prepend(ActionDispatch::Routing::MapperDecorator)
