# frozen_string_literal: true

class DropChapters < ActiveRecord::Migration[8.1]
  def change
    drop_table :chapters do |t|
      t.references :game, null: false, foreign_key: true
      t.text :summary
      t.timestamps
    end
  end
end
