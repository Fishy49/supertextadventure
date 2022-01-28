# frozen_string_literal: true

class AddCurrentContextToGamesTable < ActiveRecord::Migration[7.0]
  def change
    change_table :games, bulk: true do |t|
      t.text :current_context
      t.boolean :is_current_context_ascii, default: false
    end
  end
end
