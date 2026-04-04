# frozen_string_literal: true

require "test_helper"

class TurnManagerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_1 = 1
  USER_2 = 2
  USER_3 = 3

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => { "name" => "Tavern", "description" => "A cozy tavern.", "exits" => {} }
      }
    )
  end

  # ─── initialize_turns ──────────────────────────────────────────────────────

  test "initialize_turns sets turn order and current_index" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])
    ClassicGame::TurnManager.initialize_turns(game, [USER_1, USER_2])

    turn_state = game.game_state["turn_state"]
    assert_equal ["1", "2"], turn_state["order"]
    assert_equal 0, turn_state["current_index"]
    assert_equal({}, turn_state["combat_waiters"])
  end

  # ─── current_player ────────────────────────────────────────────────────────

  test "current_player returns the first player initially" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])

    assert_equal "1", ClassicGame::TurnManager.current_player(game)
  end

  test "current_player returns nil when no turn order initialized" do
    game = build_game(world_data: @world, player_id: USER_1)

    assert_nil ClassicGame::TurnManager.current_player(game)
  end

  # ─── user_can_act? ─────────────────────────────────────────────────────────

  test "user_can_act? returns true for the current player" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])

    assert ClassicGame::TurnManager.user_can_act?(game, USER_1)
    assert_not ClassicGame::TurnManager.user_can_act?(game, USER_2)
  end

  test "user_can_act? always returns true when no turn order exists (single-player)" do
    game = build_game(world_data: @world, player_id: USER_1)

    assert ClassicGame::TurnManager.user_can_act?(game, USER_1)
  end

  test "user_can_act? always returns true when only one player in order" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1])

    assert ClassicGame::TurnManager.user_can_act?(game, USER_1)
  end

  # ─── advance ───────────────────────────────────────────────────────────────

  test "advance moves to next player" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])

    ClassicGame::TurnManager.advance(game)

    assert_equal "2", ClassicGame::TurnManager.current_player(game)
  end

  test "advance wraps around to first player" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])

    ClassicGame::TurnManager.advance(game) # -> player 2
    ClassicGame::TurnManager.advance(game) # -> player 1

    assert_equal "1", ClassicGame::TurnManager.current_player(game)
  end

  test "advance skips combat waiters" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2, USER_3])
    ClassicGame::TurnManager.add_combat_waiter(game, USER_2, "tavern")

    ClassicGame::TurnManager.advance(game) # player 1 -> skip player 2 -> player 3

    assert_equal "3", ClassicGame::TurnManager.current_player(game)
  end

  test "advance skips multiple consecutive combat waiters" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2, USER_3])
    ClassicGame::TurnManager.add_combat_waiter(game, USER_2, "tavern")
    ClassicGame::TurnManager.add_combat_waiter(game, USER_3, "tavern")

    ClassicGame::TurnManager.advance(game) # should wrap back to player 1

    assert_equal "1", ClassicGame::TurnManager.current_player(game)
  end

  test "advance is a no-op when no turn order exists" do
    game = build_game(world_data: @world, player_id: USER_1)

    assert_nothing_raised { ClassicGame::TurnManager.advance(game) }
  end

  # ─── combat waiters ────────────────────────────────────────────────────────

  test "add_combat_waiter records the room" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])
    ClassicGame::TurnManager.add_combat_waiter(game, USER_1, "tavern")

    assert game.player_waiting_for_combat?(USER_1)
  end

  test "remove_combat_waiter clears the player" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])
    ClassicGame::TurnManager.add_combat_waiter(game, USER_1, "tavern")
    ClassicGame::TurnManager.remove_combat_waiter(game, USER_1)

    assert_not game.player_waiting_for_combat?(USER_1)
  end

  test "clear_combat_waiters_for_room removes all waiters in that room" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2, USER_3])
    ClassicGame::TurnManager.add_combat_waiter(game, USER_1, "tavern")
    ClassicGame::TurnManager.add_combat_waiter(game, USER_2, "tavern")
    ClassicGame::TurnManager.add_combat_waiter(game, USER_3, "library")

    ClassicGame::TurnManager.clear_combat_waiters_for_room(game, "tavern")

    assert_not game.player_waiting_for_combat?(USER_1)
    assert_not game.player_waiting_for_combat?(USER_2)
    assert game.player_waiting_for_combat?(USER_3)
  end

  # ─── waiting_message ───────────────────────────────────────────────────────

  test "waiting_message returns a string with the current player name" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      game_users: [
        OpenStruct.new(user_id: USER_1, character_name: "Gandalf"),
        OpenStruct.new(user_id: USER_2, character_name: "Aragorn")
      ]
    )

    msg = ClassicGame::TurnManager.waiting_message(game)

    assert_match(/Gandalf/i, msg)
    assert_match(/turn/i, msg)
  end

  test "waiting_message falls back gracefully when no game_users" do
    game = build_multiplayer_game(world_data: @world, player_ids: [USER_1, USER_2])

    assert_nothing_raised { ClassicGame::TurnManager.waiting_message(game) }
  end
end
