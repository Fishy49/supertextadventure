# frozen_string_literal: true

Rails.application.routes.draw do
  get "messages/create"
  root "home#index"

  resources :users

  resources :sessions, only: %i[new create destroy]

  get "games/list", to: "games#list", as: :games_list
  resources :games
  get "games/:id/lobby", to: "games#lobby", as: :game_lobby
  patch "games/:id/join", to: "games#join", as: :join_game

  post "messages", to: "messages#create", as: :create_message

  get "signup", to: "users#new", as: :signup
  get "login", to: "sessions#new", as: :login
  get "logout", to: "sessions#destroy", as: :logout

  get "tavern", to: "games#index", as: :tavern

  get "about", to: "about#index"
end
