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

  before_create :set_uuid

  after_save :broadcast_context, :will_save_change_to_current_context?

  validates :created_by, presence: true

  def game_user(user)
    game_users.find_by(user_id: user.id)
  end

  def host?(user)
    created_by == user&.id
  end

  def user_in_game?(user)
    game_users.pluck(:user_id).include?(user.id)
  end

  def can_user_join?(user)
    !user_in_game?(user) && !host?(user) && !max_players?
  end

  def max_players?
    game_users.count == max_players
  end

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
    end

    def broadcast_context
      broadcast_replace_to(self, :state, target: :context, partial: "/games/current_context",
                                           locals: { game: self })
    end
end
