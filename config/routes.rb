# frozen_string_literal: true
#
HykuKnapsack::Engine.routes.draw do
  mount Hyrax::Engine, at: '/'
  get 'id/:id', to: 'original_id#show', constraints: { id: /[^\/]+/ }
  get 'OrderDetails.do', to: 'original_id#show2'

end
