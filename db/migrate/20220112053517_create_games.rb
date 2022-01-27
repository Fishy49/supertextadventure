# frozen_string_literal: true

class CreateGames < ActiveRecord::Migration[7.0]
  def change
    create_table :games do |t|
      t.string :uuid
      t.string :name
      t.text :description
      t.string :game_type
      t.integer :created_by
      t.string :status
      t.string :host_display_name
      t.datetime :opened_at
      t.datetime :closed_at
      t.boolean :is_friends_only
      t.integer :max_players

      t.timestamps

      t.index [:uuid], unique: true
      t.index [:name], unique: true
    end
  end
end
