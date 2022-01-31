# frozen_string_literal: true

class AddHealthToGameUsersTable < ActiveRecord::Migration[7.0]
  def change
    change_table :game_users, bulk: true do |t|
      t.integer :max_health
      t.integer :current_health
    end
  end
end
