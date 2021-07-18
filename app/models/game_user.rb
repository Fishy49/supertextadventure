# frozen_string_literal: true

class GameUser < ApplicationRecord
  belongs_to :user
  belongs_to :game

  validates :status, presence: true
end
