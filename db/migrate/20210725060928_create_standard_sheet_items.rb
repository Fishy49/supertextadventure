class CreateStandardSheetItems < ActiveRecord::Migration[6.1]
  def change
    create_join_table :standard_stat_sheets, :standard_items
  end
end
