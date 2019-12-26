class FriendRequest < ApplicationRecord
  belongs_to :user
  belongs_to :requestee, foreign_key: :friend_id, class_name: 'User'
end
