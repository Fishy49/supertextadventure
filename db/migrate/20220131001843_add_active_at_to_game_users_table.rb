# frozen_string_literal: true

class AddActiveAtToGameUsersTable < ActiveRecord::Migration[7.0]
  def change
    add_column :game_users, :active_at, :datetime
  end
end
