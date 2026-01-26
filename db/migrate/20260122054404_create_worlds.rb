class CreateWorlds < ActiveRecord::Migration[8.0]
  def change
    create_table :worlds do |t|
      t.string :name
      t.text :description
      t.jsonb :world_data

      t.timestamps
    end
  end
end
