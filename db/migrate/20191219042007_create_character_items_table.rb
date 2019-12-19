class CreateCharacterItemsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :character_items_tables do |t|
      t.references :character
      t.string :name
      t.string :item_type
      t.string :description
      t.integer :damage
      t.integer :healing
      t.integer :armor
    end
  end
end
