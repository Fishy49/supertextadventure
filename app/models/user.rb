# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  validates :username, presence: true, uniqueness: true

  has_many :hosted_games, class_name: "Game", foreign_key: :created_by, dependent: :destroy, inverse_of: :host

  has_many :game_users, inverse_of: :user, dependent: :destroy

  has_many :joined_games, through: :game_users, class_name: "Game", source: :game

  def awesome?
    true
  end
end
