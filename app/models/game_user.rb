# frozen_string_literal: true

class GameUser < ApplicationRecord
  belongs_to :game, inverse_of: :game_users
  belongs_to :user, inverse_of: :game_users
  has_many :messages, inverse_of: :game_user, dependent: :destroy

  scope :active, -> { where(is_active: true) }
end
