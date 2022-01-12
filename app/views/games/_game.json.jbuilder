# frozen_string_literal: true

json.extract! game, :id, :uuid, :name, :game_type, :created_by, :status, :opened_at, :closed_at, :is_friends_only,
              :max_players, :created_at, :updated_at
json.url game_url(game, format: :json)
