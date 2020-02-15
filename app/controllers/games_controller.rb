class GamesController < ApplicationController
  def index
    @games = []
    if params[:my_games].present? || params[:friendly_games].present?
      @games = current_user.games if params[:my_games].present?
      @games += current_user.friends.map(&:games).flatten
    else
      @games = Game.all
    end

    respond_to :js
  end

  def show
    @game = Game.find(params[:id])
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.create game_params.merge(created_by: current_user.id)
    @game.games_users.create user_id: current_user.id, role: "dm"

    flash[:success] = "Game Created Successfully! You can now prepare content and invite players."

    redirect_to game_path @game
  end

  private

  def game_params
    params.require(:game).permit([:id, :name, :mode, :description, :max_players, :is_friends_only])
  end
end
