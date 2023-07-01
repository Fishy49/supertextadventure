# frozen_string_literal: true

class GameUser < ApplicationRecord
  belongs_to :game, inverse_of: :game_users
  belongs_to :user, inverse_of: :game_users
  has_many :messages, inverse_of: :game_user, dependent: :nullify
  # has_many :inventory, class_name: "InventoryItem", inverse_of: :game_user, dependent: :destroy

  scope :joined, -> { order(id: :asc) }

  before_create :check_game_users_count
  before_create :set_starting_health

  after_create_commit :broadcast_new_player
  after_create_commit :inform_ai_of_player, if: proc { game.game_type == "chatgpt" }

  after_update_commit :create_health_change_event_message, if: :saved_change_to_current_health?
  after_update_commit :broadcast_updated_player_health, if: :saved_change_to_current_health?
  after_update_commit :broadcast_updated_player_mute, if: :saved_change_to_can_message?
  after_update_commit :broadcast_updated_player_active, if: :saved_change_to_active_at?

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
                                           locals: { game_users: game.game_users.joined, for_host: false })
      broadcast_replace_to(game, :host_players, target: :players, partial: "/games/players",
                                                locals: { game_users: game.game_users.joined, for_host: true })
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

    def broadcast_updated_player_mute
      broadcast_replace_to(game, :players, target: "game_user_#{id}", partial: "/games/player",
                                           locals: { game_user: self, for_host: false })
    end

    def broadcast_updated_player_active
      broadcast_replace_to(game, :players, target: "game_user_#{id}", partial: "/games/player",
                                           locals: { game_user: self, for_host: false })
      broadcast_replace_to(game, :host_players, target: "game_user_#{id}", partial: "/games/player",
                                                locals: { game_user: self, for_host: true })
    end

    def chat_log_with_intro_request
      chat_log = game.messages_for_ai
      chat_log << { role: "user",
                    content: "Please introduce the character named \"#{character_name}\"
                    that just joined the game to the rest of the players." }
    end

    def inform_ai_of_player
      Message.create(
        game_id: game.id,
        is_system_message: true,
        content: "A player with the name \"#{character_name}\" has joined the game.
        They are described as follows: \"#{character_description}\""
      )

      client = OpenAI::Client.new
      response = client.chat(
        parameters: {
          model: "gpt-4",
          messages: chat_log_with_intro_request
        }
      )
      ai_response = response.dig("choices", 0, "message", "content")

      Message.create(game_id: game.id, content: ai_response)
    end
end
