# frozen_string_literal: true

class TavernController < ApplicationController
  before_action :authorize!

  def index; end

  def games
    @games = Game.limit(10)
    render :index
  end

  def new_game
    @game = Game.new(created_by: current_user.id)
    render :index
  end

  private

  def authorize!
    redirect_to root_url, notice: "Away with ye! The tavern is for adventurers only!" unless logged_in?
  end
end
