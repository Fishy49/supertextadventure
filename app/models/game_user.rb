# frozen_string_literal: true

class GameUser < ApplicationRecord
  belongs_to :game, inverse_of: :game_users
  belongs_to :user, inverse_of: :game_users
  has_many :messages, inverse_of: :game_user, dependent: :destroy
  has_many :inventory, class_name: "InventoryItem", inverse_of: :game_user, dependent: :destroy

  scope :active, -> { where(is_active: true) }
  scope :online, -> { where(is_online: true) }
  scope :typing, -> { where(is_typing: true) }

  before_create :check_game_users_count
  before_create :set_starting_health

  private

    def check_game_users_count
      return unless game.max_players?

      errors.add(:base, "Game is full.")
      raise ActiveRecord::RecordInvalid, self
    end

    def set_starting_health
      if game.enable_hp?
        self.max_health = game.starting_hp
        self.current_health = game.starting_hp
      end
    end
end
