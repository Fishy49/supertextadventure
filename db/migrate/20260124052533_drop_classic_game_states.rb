# frozen_string_literal: true

class DropClassicGameStates < ActiveRecord::Migration[8.0]
  def change
    drop_table :classic_game_states, if_exists: true
  end
end
