# frozen_string_literal: true

json.extract! game, :id, :name, :game_type, :users_id, :status, :opened_at, :closed_at, :is_friends_only, :max_players,
              :created_at, :updated_at
json.url game_url(game, format: :json)
