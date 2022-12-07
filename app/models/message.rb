# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :game
  belongs_to :game_user, optional: true

  serialize :event_data

  scope :latest, -> { order(:id).last(50) }

  before_create :parse_dice_rolls

  after_create_commit -> { broadcast_append_to(game, :messages) }
  after_create_commit :set_user_active

  def event?
    event_type.present?
  end

  def display_name
    return sender_name if sender_name.present?

    game_user&.character_name || game.host_display_name
  end

  def host_message?
    !event? && game_user.nil?
  end

  private

    def parse_dice_rolls
      return unless content.downcase.starts_with?("roll ")

      self.event_type = "roll"

      arguments = content.downcase.delete("roll ")

      self.event_data = DiceRoll.new(arguments)
    end

    def set_user_active
      game_user.update(active_at: DateTime.now) unless host_message?
    end
end
