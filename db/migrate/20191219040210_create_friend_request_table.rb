class CreateFriendRequestTable < ActiveRecord::Migration[6.0]
  def change
    create_table :friend_requests do |t|
      t.references :user
      t.integer :friend_id
      t.boolean :is_accepted
      t.boolean :is_rejected
      t.datetime :responded_at, null: true, default: nil
      t.string :message, default: ''
      t.string :timestamps

      t.index [:friend_id]
    end
  end
end
