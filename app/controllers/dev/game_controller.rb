# frozen_string_literal: true

module Dev
  class GameController < ApplicationController
    DEV_USERNAME = "dev_player"

    before_action :require_development!

    # GET /dev/game
    def show
      dev_user = find_or_create_dev_user
      session[:user_id] = dev_user.id

      world = World.find_by(name: "QA Test World")
      return render :missing_world, status: :ok if world.nil?

      game = Game.find_by(created_by: dev_user.id, game_type: :classic)
      game ||= Game.create!(
        created_by: dev_user.id,
        game_type: :classic,
        name: "Dev Game [#{dev_user.id}]",
        world: world,
        status: "open"
      )

      GameUser.find_or_create_by!(game: game, user: dev_user) do |gu|
        gu.character_name = "Dev Player"
      end

      session[:dev_game_id] = game.id

      redirect_to game_path(id: game.uuid)
    end

    # DELETE /dev/game
    def destroy
      dev_user = User.find_by(username: DEV_USERNAME)
      game = Game.find_by(created_by: dev_user&.id, game_type: :classic)
      game&.destroy

      refresh_qa_world

      session.delete(:dev_game_id)

      redirect_to dev_game_path
    end

    private

      def refresh_qa_world
        load Rails.root.join("test/support/qa_world_data.rb")
        world = World.find_or_initialize_by(name: "QA Test World")
        world.description ||= "A full-featured world for QA / developer testing"
        world.world_data = TestSupport::QaWorldData.data
        world.save!
      end

      def find_or_create_dev_user
        User.find_or_create_by!(username: DEV_USERNAME) do |u|
          u.password = SecureRandom.hex(16)
        end
      end

      def require_development!
        raise ActionController::RoutingError, "Not Found" if rails_env.production?
      end

      def rails_env
        Rails.env
      end
  end
end
