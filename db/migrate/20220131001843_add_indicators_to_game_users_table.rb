# frozen_string_literal: true

class AddIndicatorsToGameUsersTable < ActiveRecord::Migration[7.0]
  def change
    change_table :game_users, bulk: true do |t|
      t.boolean :is_typing
      t.boolean :is_blocked
    end
  end
end
