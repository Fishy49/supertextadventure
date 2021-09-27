# frozen_string_literal: true

class GameMessage < ApplicationRecord
  belongs_to :game
  belongs_to :user
  belongs_to :game_event
  has_rich_text :content
end
