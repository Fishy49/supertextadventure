# frozen_string_literal: true

class CreateGameUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :game_users do |t|
      t.references :game
      t.references :user
      t.string :status
      t.datetime :invited_at
      t.datetime :joined_at
      t.datetime :left_at
      t.datetime :kicked_at
      t.datetime :banned_at

      t.timestamps

      t.index [:game_id, :user_id], unique: true
    end
  end
end
