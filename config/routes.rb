# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  resources :users

  resources :sessions, only: %i[new create destroy]

  resources :games
  get "games/:id/lobby", to: "games#lobby", as: :game_lobby
  patch "games/:id/join", to: "games#join", as: :join_game

  get "signup", to: "users#new", as: :signup
  get "login", to: "sessions#new", as: :login
  get "logout", to: "sessions#destroy", as: :logout

  get "tavern", to: "tavern#index"
  get "tavern/games", to: "tavern#games"
  get "tavern/new-game", to: "tavern#new_game"

  get "about", to: "about#index"
end
