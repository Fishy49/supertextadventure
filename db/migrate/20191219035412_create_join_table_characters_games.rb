class CreateJoinTableCharactersGames < ActiveRecord::Migration[6.0]
  def change
    create_join_table :characters, :games do |t|
      # t.index [:character_id, :game_id]
      # t.index [:game_id, :character_id]
    end
  end
end
