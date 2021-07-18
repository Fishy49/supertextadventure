# frozen_string_literal: true

class CreateGames < ActiveRecord::Migration[6.1]
  def change
    create_table :games do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :game_type
      t.string :status
      t.text :description
      t.boolean :is_friends_only
      t.integer :max_players
      t.datetime :opened_at
      t.datetime :closed_at

      t.timestamps
    end
  end
end
