class UsersFriends < ApplicationRecord
  belongs_to :user, foreign_key: :user_id, class_name: 'User', inverse_of: :friends
  belongs_to :friend, foreign_key: :friend_id, class_name: 'User', inverse_of: :friends, optional: true
end
