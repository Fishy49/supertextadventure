# frozen_string_literal: true

class GameUser < ApplicationRecord
  belongs_to :game, inverse_of: :game_users
  belongs_to :user, inverse_of: :game_users
  has_many :messages, inverse_of: :game_user, dependent: :destroy

  scope :active, -> { where(is_active: true) }
  scope :online, -> { where(is_online: true) }
  scope :typing, -> { where(is_typing: true) }

  before_create :check_game_users_count

  after_save :broadcast_presence, :will_save_change_to_is_online?
  after_save :broadcast_typing, :will_save_change_to_is_typing?
  after_save :broadcast_block, :will_save_change_to_is_blocked?

  private

    def check_game_users_count
      return unless game.max_players?

      errors.add(:base, "Game is full.")
      raise ActiveRecord::RecordInvalid, self
    end

    def broadcast_presence
      # broadcast_replace_to(game, :state, target: :context, partial: "/games/current_context",
      # locals: { game: self })
    end

    def broadcast_typing
      broadcast_replace_to(game, :state, target: :typing, partial: "/games/typing_indicators",
                                         locals: { typers: game.game_users.typing })
    end

    def broadcast_block
      # broadcast_replace_to(game, :state, target: :context, partial: "/games/current_context",
      # locals: { game: self })
    end
end
