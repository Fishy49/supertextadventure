class CreateCharacters < ActiveRecord::Migration[6.1]
  def change
    create_table :characters do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :race
      t.string :height
      t.string :hair_color
      t.string :eye_color
      t.text :backstory

      t.timestamps
    end
  end
end
