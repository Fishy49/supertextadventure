# frozen_string_literal: true

class CreateGameUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :game_users do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :character_name, null: false
      t.boolean :is_active, default: true

      t.timestamps

      t.index %i[game_id user_id], unique: true
    end
  end
end
