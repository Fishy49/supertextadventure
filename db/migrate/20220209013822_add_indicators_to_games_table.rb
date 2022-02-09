# frozen_string_literal: true

class AddIndicatorsToGamesTable < ActiveRecord::Migration[7.0]
  def change
    change_table :games, bulk: true do |t|
      t.boolean :is_host_online, default: false
      t.datetime :host_online_at
      t.boolean :is_host_typing, default: false
      t.datetime :host_typing_at
    end
  end
end
