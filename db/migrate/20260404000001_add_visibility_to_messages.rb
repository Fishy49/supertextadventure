# frozen_string_literal: true

class AddVisibilityToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :visible_to_user_ids, :jsonb, default: [], null: false
    add_column :messages, :room_id, :string
  end
end
