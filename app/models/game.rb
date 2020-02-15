class Game < ApplicationRecord
  belongs_to :creator, class_name: "User", foreign_key: :created_by, optional: true, inverse_of: :created_games

  has_many :games_users, dependent: :nullify, join_table: :games_users, class_name: "GamesUsers"
  has_many :users, through: :games_users

  has_many :game_messages, dependent: :nullify

  def full?
    users.count == max_players
  end

  def user_can_join?(user, is_spectator = false)
    return false if full?
    return false if is_friends_only? && creator.friends.exclude?(user)
    return false if is_spectator && !is_spectator_game?
    true
  end
end
