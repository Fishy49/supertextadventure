# frozen_string_literal: true

class AddCharacterDescriptionToGameUsersTable < ActiveRecord::Migration[7.0]
  def change
    add_column :game_users, :character_description, :text
  end
end
