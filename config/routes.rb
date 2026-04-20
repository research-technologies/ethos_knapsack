# frozen_string_literal: true
#
HykuKnapsack::Engine.routes.draw do
  mount Hyrax::Engine, at: '/'
  get 'OrderDetails.do', to: 'original_id#show'
  
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#rejected", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

end
