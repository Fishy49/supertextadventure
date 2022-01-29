# frozen_string_literal: true

class CreateInventoryItems < ActiveRecord::Migration[7.0]
  def change
    create_table :inventory_items do |t|
      t.references :game_user, null: false, foreign_key: true
      t.string :name
      t.integer :quantity
      t.text :description
      t.text :ascii

      t.timestamps
    end
  end
end
