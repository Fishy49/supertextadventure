# frozen_string_literal: true

Rails.application.routes.draw do
  resources :games
  root "home#index"

  resources :users
  resources :sessions, only: %i[new create destroy]

  get "signup", to: "users#new", as: :signup
  get "login", to: "sessions#new", as: :login
  get "logout", to: "sessions#destroy", as: :logout

  get "tavern", to: "tavern#index"
end
