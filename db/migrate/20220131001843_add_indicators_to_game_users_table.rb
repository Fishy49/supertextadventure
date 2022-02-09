# frozen_string_literal: true

class AddIndicatorsToGameUsersTable < ActiveRecord::Migration[7.0]
  def change
    change_table :game_users, bulk: true do |t|
      t.boolean :is_online, default: false
      t.datetime :online_at
      t.boolean :is_typing, default: false
      t.datetime :typing_at
      t.boolean :is_blocked, default: false
    end
  end
end
