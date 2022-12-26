# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.blank?

    can %i[index list lobby], Game
    can :join, Game, status: "open"
    can :manage, Game, host: user
    can :show, Game, { game_users: { user: user } }

    can :create, GameUser
    can :update, GameUser, { game: { host: user } }
  end
end
