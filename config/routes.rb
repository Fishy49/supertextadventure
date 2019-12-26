Rails.application.routes.draw do
  devise_for :users
  root to: 'main#index'

  resources :lobby
  resources :games
  resources :game_messages
end
