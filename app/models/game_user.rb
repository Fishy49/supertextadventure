# frozen_string_literal: true

class GameUser < ApplicationRecord
  belongs_to :game, inverse_of: :game_users
  belongs_to :user, inverse_of: :game_users

  scope :active, -> { where(is_active: true) }
end
