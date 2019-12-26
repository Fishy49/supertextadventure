class CreateGameTable < ActiveRecord::Migration[6.0]
  def change
    create_table :games do |t|
      t.integer :created_by
      t.string :name
      t.string :mode
      t.text :description, default: ''
      t.integer :max_players
      t.boolean :is_friends_only
      t.string :status
      t.json :object, null: true, default: nil
      t.timestamps
    end
  end
end
