# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    dependent: :destroy,
                    inverse_of: :hosted_games,
                    optional: true

  has_many :game_users, inverse_of: :game, dependent: :nullify

  before_create :set_uuid

  def host?(user)
    created_by == user&.id
  end

  def can_user_join?(user)
    # TODO: check to see if game is open and user is a friend of host
    user.awesome?
  end

  private

  def set_uuid
    self.uuid = SecureRandom.uuid
  end
end
