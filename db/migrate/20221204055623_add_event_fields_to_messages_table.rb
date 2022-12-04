class AddEventFieldsToMessagesTable < ActiveRecord::Migration[7.0]
  def change
    remove_column :messages, :is_event, :boolean, default: false
    add_column :messages, :event_type, :string
    add_column :messages, :event_data, :text
  end
end
