# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :game
  belongs_to :game_user, optional: true

  scope :latest, -> { order(:id).last(50) }

  after_create_commit -> { broadcast_append_to(game, :messages) }

  def display_name
    return sender_name if sender_name.present?

    game_user&.chacter_name || game.host_display_name
  end
end
