# frozen_string_literal: true

class CreateSetupTokensTable < ActiveRecord::Migration[7.0]
  def change
    create_table :setup_tokens do |t|
      t.string :uuid
      t.boolean :is_active, default: true
      t.references :users, null: true
      t.timestamps
    end
  end
end
