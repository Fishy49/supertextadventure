class CreateStandardItems < ActiveRecord::Migration[6.1]
  def change
    create_table :standard_items do |t|
      t.string :name
      t.string :item_type
      t.text :description
      t.string :modifier_type
      t.integer :modifier

      t.timestamps
    end
  end
end
