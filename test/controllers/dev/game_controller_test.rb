# frozen_string_literal: true

require "test_helper"

module Dev
  class GameControllerTest < ActionDispatch::IntegrationTest
    DEV_USER_ID = Dev::GameController::DEV_USER_ID

    QA_WORLD_DATA = {
      "meta" => { "starting_room" => "start", "version" => "1.0" },
      "rooms" => {
        "start" => {
          "name" => "Test Room",
          "description" => "A plain room for testing.",
          "exits" => {}
        }
      },
      "items" => {},
      "npcs" => {},
      "creatures" => {}
    }.freeze

    setup do
      @qa_world = World.find_or_create_by!(name: "QA Test World") do |w|
        w.world_data = QA_WORLD_DATA.deep_dup
      end
    end

    teardown do
      Game.where(created_by: DEV_USER_ID).destroy_all
      World.where(name: "QA Test World").destroy_all
    end

    # ─── GET /dev/game ────────────────────────────────────────────────────────

    test "GET /dev/game sets dev session and redirects to game" do
      get "/dev/game"

      assert_response :redirect
      assert_match %r{/games/}, response.location
      assert_equal DEV_USER_ID, session[:user_id]
    end

    test "GET /dev/game creates a game on first visit" do
      assert_difference "Game.where(created_by: #{DEV_USER_ID}).count", 1 do
        get "/dev/game"
      end
    end

    test "GET /dev/game reuses existing dev game and does not duplicate" do
      get "/dev/game"

      assert_no_difference "Game.where(created_by: #{DEV_USER_ID}).count" do
        get "/dev/game"
      end
    end

    test "GET /dev/game stores dev_game_id in session" do
      get "/dev/game"

      game = Game.find_by!(created_by: DEV_USER_ID, game_type: "classic")
      assert_equal game.id, session[:dev_game_id]
    end

    test "GET /dev/game shows missing world error when QA Test World does not exist" do
      @qa_world.destroy

      get "/dev/game"

      assert_response :ok
      assert_match "bin/rails db:seed", response.body
    end

    # ─── DELETE /dev/game ─────────────────────────────────────────────────────

    test "DELETE /dev/game destroys dev game and redirects back to /dev/game" do
      get "/dev/game"
      assert Game.find_by(created_by: DEV_USER_ID, game_type: "classic")

      delete "/dev/game"

      assert_redirected_to "/dev/game"
      assert_nil Game.find_by(created_by: DEV_USER_ID, game_type: "classic")
    end

    test "DELETE /dev/game clears dev_game_id from session" do
      get "/dev/game"
      delete "/dev/game"

      assert_nil session[:dev_game_id]
    end

    test "DELETE /dev/game does not raise when no dev game exists" do
      delete "/dev/game"

      assert_redirected_to "/dev/game"
    end

    # ─── Production guard ─────────────────────────────────────────────────────

    test "dev controller raises RoutingError in production environment" do
      controller = Dev::GameController.new

      production_env = ActiveSupport::StringInquirer.new("production")

      # Temporarily override rails_env on the singleton class to simulate production
      controller.define_singleton_method(:rails_env) { production_env }

      assert_raises ActionController::RoutingError do
        controller.send(:require_development!)
      end
    end
  end
end
