# frozen_string_literal: true

class AddVisibleToUserIdsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :visible_to_user_ids, :integer, array: true, default: nil
  end
end
