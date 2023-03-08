# frozen_string_literal: true

class AddIsSystemMessageToMessagesTable < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :is_system_message, :boolean, default: false
  end
end
