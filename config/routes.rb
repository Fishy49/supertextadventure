# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  get 'setup', to: "setup#index", as: :setup
  post 'setup/save', to: "setup#save", as: :save_setup
  get 'setup/list-tokens', to: "setup#list_tokens"
  post 'setup/create-token', to: "setup#create_token"
  delete 'setup/delete-token', to: "setup#delete_token"

  resources :users

  resources :sessions, only: %i[new create destroy]

  get "games/list", to: "games#list", as: :games_list

  resources :games do
    patch "current-context", to: "games/current_context#update", as: :update_context
    get "current-context/edit", to: "games/current_context#edit", as: :edit_context

    patch "host/online", to: "games/host#online"
    patch "host/offline", to: "games/host#offline"
    patch "host/typing", to: "games/host#typing"
    patch "host/stop-typing", to: "games/host#stop_typing"
  end
  resources :inventory_items

  get "games/:id/lobby", to: "games#lobby", as: :game_lobby
  patch "games/:id/join", to: "games#join", as: :join_game

  patch "game_users/:id/online", to: "game_users#online"
  patch "game_users/:id/offline", to: "game_users#offline"
  patch "game_users/:id/typing", to: "game_users#typing"
  patch "game_users/:id/stop-typing", to: "game_users#stop_typing"
  patch "game_users/:id/update-health", to: "game_users#update_health", as: :game_user_update_health

  get "messages", to: "messages#index", as: :messages
  post "messages", to: "messages#create", as: :create_message
  get "messages/create"

  get "signup", to: "users#new", as: :signup
  get "login", to: "sessions#new", as: :login
  get "logout", to: "sessions#destroy", as: :logout

  get "tavern", to: "games#index", as: :tavern

  get "about", to: "about#index"
end
