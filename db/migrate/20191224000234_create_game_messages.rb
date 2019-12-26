class CreateGameMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :game_messages do |t|
      t.references :game
      t.references :user
      t.text :body
      t.json :meta
      t.timestamps
    end
  end
end
