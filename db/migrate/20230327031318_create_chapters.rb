# frozen_string_literal: true

class CreateChapters < ActiveRecord::Migration[7.0]
  def change
    create_table :chapters do |t|
      t.references :game, null: false, foreign_key: true
      t.references :first_message, index: true, foreign_key: { to_table: :messages }
      t.references :last_message, index: true, foreign_key: { to_table: :messages }
      t.integer :number
      t.text :name
      t.text :summary

      t.timestamps
    end
  end
end
