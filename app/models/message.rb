# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :game
  belongs_to :user

  after_create_commit -> { broadcast_append_to(game, :messages) }
end
