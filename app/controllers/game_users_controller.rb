# frozen_string_literal: true

class GameUsersController < ApplicationController
  before_action :set_game_user

  def update_health
    heal = game_user_params[:heal].presence&.to_i || 0
    damage = game_user_params[:damage].presence&.to_i || 0
    total_health_change = heal - damage

    @game_user.update(current_health: @game_user.current_health + total_health_change)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("game_user_#{@game_user.id}", partial: "/games/player",
                                                                                locals: { 
                                                                                  game_user: @game_user,
                                                                                  for_host: true
                                                                                })
      end
      format.html
    end
  end

  private

    def set_game_user
      @game_user = GameUser.find(params[:id])
    end

    def game_user_params
      params.require(:game_user).permit(:heal, :damage)
    end
end
