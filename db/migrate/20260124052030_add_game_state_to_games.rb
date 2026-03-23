# frozen_string_literal: true

class AddGameStateToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :game_state, :jsonb, default: {}, null: false
  end
end
