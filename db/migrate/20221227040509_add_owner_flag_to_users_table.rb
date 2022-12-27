# frozen_string_literal: true

class AddOwnerFlagToUsersTable < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :is_owner, :boolean, default: false
  end
end
