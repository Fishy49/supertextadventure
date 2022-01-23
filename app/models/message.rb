# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :game
  belongs_to :user

  # after_create_commit -> { broadcast_append_to game }

  validates %i[game_id user_id], presence: true
end
