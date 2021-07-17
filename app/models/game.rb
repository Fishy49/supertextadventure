# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :user
  has_many :game_users, inverse_of: :user, dependent: :nullify
end
