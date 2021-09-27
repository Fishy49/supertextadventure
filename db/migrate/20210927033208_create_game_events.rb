# frozen_string_literal: true

class CreateGameEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :game_events do |t|
      t.references :game, null: false, foreign_key: true
      t.string :event_type
      t.string :event_status

      t.timestamps
    end
  end
end
