# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :game
  belongs_to :game_user, optional: true

  serialize :event_data

  scope :latest, -> { order(id: :desc) }
  scope :oldest, -> { order(id: :asc) }
  scope :for_game, ->(game) { where(game_id: game.id, is_system_message: false).latest }
  scope :for_ai, -> { where(event_type: nil).oldest }

  before_create :parse_dice_rolls

  after_create_commit -> { broadcast_append_to(game, :messages) }, unless: proc { is_system_message? }
  after_update_commit -> { broadcast_replace_to(game, :messages) }, unless: proc { is_system_message? }
  after_create_commit :set_user_active_at, unless: proc { is_system_message? }
  after_create_commit :create_ai_response, if: proc { player_message? }

  def chapter
    Chapter.where(first_message_id: id).or(Chapter.where(last_message_id: id)).first
  end

  def event?
    event_type.present?
  end

  def host_message?
    game_user.nil?
  end

  def player_message?
    !event? && !host_message? && !is_system_message?
  end

  def display_name
    return sender_name if sender_name.present?

    game_user&.character_name || game.host_display_name
  end

  private

    def parse_dice_rolls
      return unless content&.downcase&.starts_with?("/roll ")

      self.event_type = "roll"

      arguments = content.downcase.delete("/roll")

      self.event_data = DiceRoll.new(arguments)
    end

    def set_user_active_at
      game_user.update(active_at: DateTime.now) unless host_message?
    end

    def create_ai_response
      # Time to close a chapter
      game.current_chapter.close! if game.current_token_count >= Game::MAX_TOKENS_FOR_AI_CHAPTER

      AiChatMessageJob.perform_async(game.id)
    end
end
