# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.blank?

    can :read, Game do |game|
      game.game_users.include?(user)
    end
    can :manage, Game, host: user

    can :create, GameUser
    can :update, GameUser, { game: { host: user } }
  end
end
