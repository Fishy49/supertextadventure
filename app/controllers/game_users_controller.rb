# frozen_string_literal: true

class GameUsersController < ApplicationController
  before_action :set_game_user

  def online
    @game_user.update(is_online: true, online_at: DateTime.now)
    head :ok
  end

  def offline
    @game_user.update(is_online: false, is_typing: false)
    head :ok
  end

  def typing
    @game_user.update(is_typing: true, typing_at: DateTime.now)
    head :ok
  end

  def stop_typing
    @game_user.update(is_typing: false)
    head :ok
  end

  private

    def set_game_user
      @game_user = GameUser.find(params[:id])
    end
end
