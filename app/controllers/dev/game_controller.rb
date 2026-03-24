# frozen_string_literal: true

module Dev
  class GameController < ApplicationController
    DEV_USER_ID = 999_999

    before_action :require_development!

    # GET /dev/game
    def show
      session[:user_id] = DEV_USER_ID

      world = World.find_by(name: "QA Test World")
      return render :missing_world, status: :ok if world.nil?

      game = Game.find_or_create_by!(created_by: DEV_USER_ID, game_type: :classic) do |g|
        g.name = "Dev Game"
        g.world = world
        g.status = "open"
      end

      session[:dev_game_id] = game.id

      redirect_to game_path(id: game.uuid)
    end

    # DELETE /dev/game
    def destroy
      game = Game.find_by(created_by: DEV_USER_ID, game_type: :classic)
      game&.destroy

      session.delete(:dev_game_id)

      redirect_to dev_game_path
    end

    # Override current_user so that User.find is never called for the spoofed id.
    # This prevents ActiveRecord::RecordNotFound when navigating to /dev/game.
    def current_user
      if session[:user_id] == DEV_USER_ID
        @current_user ||= OpenStruct.new( # rubocop:disable Style/OpenStructUse
          id: DEV_USER_ID,
          username: "Dev Player",
          is_owner?: false
        )
      else
        super
      end
    end

    private

      def require_development!
        raise ActionController::RoutingError, "Not Found" if rails_env.production?
      end

      def rails_env
        Rails.env
      end
  end
end
