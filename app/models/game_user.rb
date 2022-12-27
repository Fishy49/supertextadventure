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

  after_create_commit :broadcast_new_player

  after_update_commit :create_health_change_event_message, if: :saved_change_to_current_health?
  after_update_commit :broadcast_updated_player_health, if: :saved_change_to_current_health?

  private

    def check_game_users_count
      return unless game.max_players?

      errors.add(:base, "Game is full.")
      raise ActiveRecord::RecordInvalid, self
    end

    def set_starting_health
      return unless game.enable_hp?

      self.max_health = game.starting_hp
      self.current_health = game.starting_hp
    end

    def broadcast_new_player
      broadcast_replace_to(game, :players, target: :players, partial: "/games/players",
                                           locals: { game_users: game.game_users, for_host: false })
      broadcast_replace_to(game, :host_players, target: :players, partial: "/games/players",
                                           locals: { game_users: game.game_users, for_host: true })
    end

    def create_health_change_event_message
      game.messages.create(
        game_user_id: game.created_by,
        event_type: "health_change",
        event_data: { previous_health: current_health_before_last_save, game_user: self }
      )
    end

    def broadcast_updated_player_health
      broadcast_replace_to(game, :players, target: "game_user_#{id}", partial: "/games/player",
                                           locals: { game_user: self, for_host: false })
    end
end
