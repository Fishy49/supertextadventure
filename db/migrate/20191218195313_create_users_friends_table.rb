class CreateUsersFriendsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :users_friends do |t|
      t.references :user
      t.integer :friend_id
      t.timestamps

      t.index [:user_id, :friend_id]
    end
  end
end
