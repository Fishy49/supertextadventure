# frozen_string_literal: true

class AddHostActiveAtToGamesTable < ActiveRecord::Migration[7.0]
  def change
    add_column :games, :host_active_at, :datetime
  end
end
