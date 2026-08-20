# frozen_string_literal: true

require "test_helper"

module Games
  class TurnOrdersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @game = games(:classic_open)
      @owner = users(:owner)
      @player1 = users(:player1)
      @player2 = users(:player2)

      @game.game_users.create!(user_id: @player1.id, character_name: "Elara")
      @game.game_users.create!(user_id: @player2.id, character_name: "Gandalf")

      state = @game.game_state.dup
      state["turn_state"] = {
        "turn_order" => [@owner.id, @player1.id, @player2.id],
        "current_index" => 0
      }
      state["player_states"] = {
        @owner.id.to_s => player_in("town_square"),
        @player1.id.to_s => player_in("town_square"),
        @player2.id.to_s => player_in("town_square")
      }
      @game.update!(game_state: state)
    end

    test "non-host cannot use turn controls" do
      log_in_as(@player1)

      post game_skip_turn_path(game_id: @game.uuid)
      assert_response :forbidden

      post game_bench_player_path(game_id: @game.uuid, user_id: @player2.id)
      assert_response :forbidden

      patch game_turn_order_path(game_id: @game.uuid),
            params: { user_ids: [@player1.id, @owner.id, @player2.id] }
      assert_response :forbidden
    end

    test "host can skip the active turn" do
      log_in_as(@owner)

      post game_skip_turn_path(game_id: @game.uuid), headers: turbo_headers

      assert_response :success
      assert_includes response.body, "host_turn_panel"
      assert_equal @player1.id, @game.reload.current_turn_user_id
      assert @game.messages.exists?(["content LIKE ?", "%skipped%"]), "skip is announced"
    end

    test "host can bench and unbench a player" do
      log_in_as(@owner)

      post game_bench_player_path(game_id: @game.uuid, user_id: @player1.id), headers: turbo_headers
      assert_response :success
      @game.reload
      assert_not_includes @game.turn_state["turn_order"], @player1.id
      assert_includes @game.benched_user_ids, @player1.id

      # The benched player is actually blocked by the engine
      result = ClassicGame::Engine.execute(game: @game, user: @player1, command_text: "look")
      assert_not result[:success]
      assert_includes result[:response], "out of the turn rotation"

      post game_unbench_player_path(game_id: @game.uuid, user_id: @player1.id), headers: turbo_headers
      assert_response :success
      assert_includes @game.reload.turn_state["turn_order"], @player1.id
    end

    test "host can reorder the rotation and the cursor follows the current player" do
      log_in_as(@owner)

      patch game_turn_order_path(game_id: @game.uuid),
            params: { user_ids: [@player2.id, @owner.id, @player1.id] },
            headers: turbo_headers

      assert_response :success
      @game.reload
      assert_equal [@player2.id, @owner.id, @player1.id], @game.turn_state["turn_order"]
      assert_equal @owner.id, @game.current_turn_user_id, "current player keeps the turn after reorder"
    end

    test "reorder is rejected when the id set does not match the rotation" do
      log_in_as(@owner)

      patch game_turn_order_path(game_id: @game.uuid),
            params: { user_ids: [@owner.id, @player1.id] }

      assert_response :unprocessable_entity
      assert_equal [@owner.id, @player1.id, @player2.id], @game.reload.turn_state["turn_order"]
    end

    test "destroying a game_user removes the player from the rotation" do
      @game.game_users.find_by(user_id: @player1.id).destroy!

      @game.reload
      assert_not_includes @game.turn_state["turn_order"], @player1.id
    end

    private

      def player_in(room_id)
        {
          "current_room" => room_id,
          "inventory" => [],
          "health" => 10,
          "max_health" => 10,
          "visited_rooms" => [],
          "flags" => {}
        }
      end

      def log_in_as(user)
        post sessions_url, params: { username: user.username, password: "testpassword" }
      end

      def turbo_headers
        { "Accept" => "text/vnd.turbo-stream.html" }
      end
  end
end
