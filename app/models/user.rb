# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  validates :username, presence: true, uniqueness: true

  has_many :friend_requests, primary_key: :id, foreign_key: :requester_id, dependent: :destroy, inverse_of: :requester
  has_many :my_friends,
           proc { where(friend_requests: { status: :accepted }) },
           through: :friend_requests,
           class_name: "User",
           source: :requestee

  has_many :received_friend_requests, class_name: "FriendRequest", primary_key: :id, foreign_key: :requestee_id,
                                      dependent: :destroy, inverse_of: :requestee
  has_many :accepted_friends,
           proc { where(friend_requests: { status: :accepted }) },
           through: :received_friend_requests,
           class_name: "User",
           source: :requestee

  has_many :games, inverse_of: :user, dependent: :destroy

  has_many :game_users, inverse_of: :user, dependent: :destroy
  %w[invited joined left kicked banned].each do |player_type|
    has_many "#{player_type}_games".to_sym,
             proc { where(game_users: { player_type: player_type }) },
             through: :game_users,
             source: :game
  end

  def friends
    (my_friends + accepted_friends).uniq
  end
end
