# frozen_string_literal: true

class AddCanMessageToGameUsersTable < ActiveRecord::Migration[7.0]
  def change
    add_column :game_users, :can_message, :boolean, default: true
  end
end
