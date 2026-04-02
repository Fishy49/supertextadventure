# frozen_string_literal: true

module Games
  class HostController < ApplicationController
    before_action :set_game
    before_action :require_host

    def online
      @game.update(is_host_online: true, host_online_at: DateTime.now)
      head :ok
    end

    def offline
      @game.update(is_host_online: false, is_typing: false)
      head :ok
    end

    def typing
      @game.update(is_host_typing: true, host_typing_at: DateTime.now)
      head :ok
    end

    def stop_typing
      @game.update(is_host_typing: false)
      head :ok
    end

    private

      def set_game
        @game = Game.where(id: params[:game_id]).or(Game.where(uuid: params[:game_id])).first!
      end

      def require_host
        head :forbidden unless @game.host?(current_user)
      end
  end
end
