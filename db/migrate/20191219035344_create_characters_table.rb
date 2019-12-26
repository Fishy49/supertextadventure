class CreateCharactersTable < ActiveRecord::Migration[6.0]
  def change
    create_table :characters do |t|
      t.references :user
      t.boolean :is_npc, default: false
      t.string :name
      t.string :class
      t.string :race
      t.integer :level
      t.integer :base_armor
      t.integer :base_str
      t.integer :base_dex
      t.integer :base_con
      t.integer :base_int
      t.integer :base_wis
      t.integer :base_cha
      t.integer :max_hp
      t.integer :current_hp
      t.integer :temporary_hp
    end
  end
end

