# frozen_string_literal: true

class CreateGameMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :game_messages do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :game_event, null: true, foreign_key: true

      t.timestamps
    end
  end
end
