class CreateJoinTableGamesUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :games_users do |t|
      t.references :game
      t.references :user
      t.string :role
    end
  end
end
