class CreateGameTable < ActiveRecord::Migration[6.0]
  def change
    create_table :games do |t|
      t.string :name
      t.string :mode
      t.string :description, default: ''
      t.integer :max_players
      t.string :timestamps
    end
  end
end
