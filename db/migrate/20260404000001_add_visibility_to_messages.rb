# frozen_string_literal: true

class AddVisibilityToMessages < ActiveRecord::Migration[8.1]
  def change
    change_table :messages, bulk: true do |t|
      t.jsonb :visible_to_user_ids, default: [], null: false
      t.string :room_id
    end
  end
end
