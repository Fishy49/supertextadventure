# frozen_string_literal: true

class AddCurrentContextToGamesTable < ActiveRecord::Migration[7.0]
  def change
    add_column :games, :current_context, :text
  end
end
