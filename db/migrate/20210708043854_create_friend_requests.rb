# frozen_string_literal: true

class CreateFriendRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :friend_requests do |t|
      t.integer :requester_id
      t.integer :requestee_id
      t.string :status
      t.datetime :accepted_on
      t.datetime :rejected_on

      t.timestamps
    end
  end
end
