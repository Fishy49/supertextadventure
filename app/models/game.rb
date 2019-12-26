class Game < ApplicationRecord
  belongs_to :creator, class_name: 'User', foreign_key: :created_by, optional: true
  has_many :games_users, dependent: :nullify, join_table: :games_users, class_name: 'GamesUsers'
  has_many :users, through: :games_users

  has_many :game_messages, dependent: :nullify
end
