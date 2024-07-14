# frozen_string_literal: true

class GameUsersController < ApplicationController
  before_action :set_game_user, except: :mute_or_unmute_all_players

  def update
    heal = game_user_params[:heal].presence.to_i
    damage = game_user_params[:damage].presence.to_i
    total_health_change = heal - damage

    @game_user.update(current_health: @game_user.current_health + total_health_change,
                      can_message: game_user_params[:can_message] == "true")

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

  def mute_or_unmute_all_players
    game = Game.find(params[:game_id])

    game.game_users.update_all(can_message: game_user_params[:can_message] == "true") # rubocop:disable Rails/SkipsModelValidations

    game.broadcast_updated_player_list

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(:players,
                                                  partial: "/games/players",
                                                  locals: {
                                                    game_users: game.game_users.joined,
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
      params.require(:game_user).permit(:heal, :damage, :can_message)
    end
end
