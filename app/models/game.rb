# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    dependent: :destroy,
                    inverse_of: :hosted_games,
                    optional: true

  before_create :set_uuid

  private

  def set_uuid
    self.uuid = SecureRandom.uuid
  end
end
