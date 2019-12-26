class CreateInventoryItemsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_items do |t|
      t.string :name
      t.string :item_type
      t.string :description
      t.integer :damage
      t.integer :healing
      t.integer :armor
    end
  end
end
