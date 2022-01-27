# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages do |t|
      t.references :game, null: false, foreign_key: true
      t.references :game_user
      t.boolean :is_event, default: false
      t.text :content

      t.timestamps
    end
  end
end
