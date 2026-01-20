# frozen_string_literal: true
#
HykuKnapsack::Engine.routes.draw do
  mount Hyrax::Engine, at: '/'
  get 'OrderDetails.do', to: 'original_id#show'
end
