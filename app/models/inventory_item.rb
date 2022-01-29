# frozen_string_literal: true

class InventoryItem < ApplicationRecord
  belongs_to :game_user
end
