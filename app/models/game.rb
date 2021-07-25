# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :user
  has_many :game_users, inverse_of: :user, dependent: :nullify

  has_many :players, 
           through: :game_users,
           source: :user
  
  has_many :active_players, 
           proc { where("game_users.status = ?", :joined) },
           through: :game_users,
           source: :user
end