# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    dependent: :destroy,
                    inverse_of: :hosted_games,
                    optional: true

  has_many :game_users, inverse_of: :game, dependent: :nullify

  has_many :messages, inverse_of: :game, dependent: :nullify

  scope :joinable_by_user, ->(user) { where(status: :open).where.not(created_by: user.id) }

  validates :created_by, presence: true

  before_create :set_uuid

  def host?(user)
    created_by == user&.id
  end

  def user_in_game?(user)
    game_users.include?(user)
  end

  def can_user_join?(user)
    !user_in_game?(user) && !host?(user)
  end

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
    end
end
