# frozen_string_literal: true

class AddEventFieldsToMessagesTable < ActiveRecord::Migration[7.0]
  def change
    change_table :messages, bulk: true do |t|
      t.remove :is_event, type: :boolean
      t.string :event_type
      t.text :event_data
    end
  end
end
