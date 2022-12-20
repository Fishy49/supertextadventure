# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    can :update, GameUser, { game: { host: user } }
  end
end
