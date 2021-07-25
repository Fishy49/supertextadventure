class CreateStandardStatSheets < ActiveRecord::Migration[6.1]
  def change
    create_table :standard_stat_sheets do |t|
      t.references :character, null: false, foreign_key: true
      t.integer :level
      t.integer :xp
      t.integer :max_hitpoints
      t.integer :current_hitpoints
      t.integer :max_spell_slots
      t.integer :current_spell_slots

      t.timestamps
    end
  end
end
