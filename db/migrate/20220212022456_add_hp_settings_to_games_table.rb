# frozen_string_literal: true

class AddHpSettingsToGamesTable < ActiveRecord::Migration[7.0]
  def change
    change_table :games, bulk: true do |t|
      t.boolean :enable_hp, default: true
      t.integer :starting_hp, default: 10
    end
  end
end
