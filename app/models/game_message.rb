# frozen_string_literal: true

class GameMessage < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :game_event, optional: true
  has_rich_text :content
  after_create_commit -> { broadcast_append_to game }
end
