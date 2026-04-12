# frozen_string_literal: true

require "test_helper"

class TurnManagerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  # ─── World fixture ──────────────────────────────────────────────────────────

  def simple_world
    build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "Tavern",
          "description" => "A busy tavern.",
          "exits" => {}
        },
        "cave" => {
          "name" => "Cave",
          "description" => "A dark cave.",
          "creatures" => ["goblin"],
          "exits" => {}
        }
      },
      creatures: {
        "goblin" => {
          "name" => "Goblin", "keywords" => ["goblin"],
          "hostile" => false, "health" => 5, "attack" => 2, "defense" => 0
        }
      }
    )
  end

  # ─── Single-player ──────────────────────────────────────────────────────────

  test "single player always can act" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: { 1 => player_state_in("tavern") }
    )

    assert ClassicGame::TurnManager.can_act?(game, 1)
  end

  test "single player can act even when turn order has one entry" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: { 1 => player_state_in("tavern") }
    )

    assert_equal [1], game.turn_state["turn_order"]
    assert ClassicGame::TurnManager.can_act?(game, 1)
  end

  # ─── Two-player turn gating ─────────────────────────────────────────────────

  test "correct player can act with two players" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("tavern"),
        2 => player_state_in("tavern")
      }
    )

    # Player 1 is first in turn order (current_index = 0)
    assert ClassicGame::TurnManager.can_act?(game, 1), "player 1 should be able to act"
    assert_not ClassicGame::TurnManager.can_act?(game, 2), "player 2 should be blocked"
  end

  test "player with pending roll can act even out of turn" do
    ps2 = player_state_in("tavern")
    ps2["pending_roll"] = { "item_id" => "potion", "dc" => 10, "dice" => "1d20" }

    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("tavern"),
        2 => ps2
      }
    )
    # It's player 1's turn but player 2 has a pending roll
    assert ClassicGame::TurnManager.can_act?(game, 2), "player with pending_roll can always act"
  end

  # ─── Turn advancement ───────────────────────────────────────────────────────

  test "advance cycles between two players" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("tavern"),
        2 => player_state_in("tavern")
      }
    )

    assert_equal 1, game.current_turn_user_id, "player 1 starts"

    ClassicGame::TurnManager.advance(game)
    assert_equal 2, game.current_turn_user_id, "should be player 2 after advance"

    ClassicGame::TurnManager.advance(game)
    assert_equal 1, game.current_turn_user_id, "wraps back to player 1"
  end

  test "advance skips player with waiting_for_combat_end" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("tavern"),
        2 => player_state_in("tavern", waiting_for_combat_end: true),
        3 => player_state_in("tavern")
      }
    )

    assert_equal 1, game.current_turn_user_id

    ClassicGame::TurnManager.advance(game)
    assert_equal 3, game.current_turn_user_id, "skips player 2 who is waiting"
  end

  test "advance is a no-op for single player" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: { 1 => player_state_in("tavern") }
    )

    ClassicGame::TurnManager.advance(game)
    assert_equal 1, game.current_turn_user_id, "single player stays on their own turn"
  end

  # ─── Waiting message ────────────────────────────────────────────────────────

  test "waiting message shows current player name" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("tavern"),
        2 => player_state_in("tavern")
      },
      character_names: { 1 => "Thorin", 2 => "Elara" }
    )

    msg = ClassicGame::TurnManager.waiting_message(game, 2)
    assert_includes msg, "Thorin", "waiting message names the current-turn player"
    assert_includes msg, "not your turn"
  end

  # ─── Combat mode ────────────────────────────────────────────────────────────

  test "enter_combat_mode sets combat turn order" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("cave"),
        2 => player_state_in("cave")
      }
    )

    with_deterministic_rand(42) do
      ClassicGame::TurnManager.enter_combat_mode(game, "cave", "goblin")
    end

    order = game.turn_state["combat_turn_order"]
    assert order.is_a?(Array), "combat_turn_order should be an array"
    assert_equal 3, order.length, "should have 2 players + 1 creature"

    ids = order.pluck("id")
    assert_includes ids, "1"
    assert_includes ids, "2"
    assert_includes ids, "goblin"
  end

  test "remove_from_combat removes the player" do
    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("cave"),
        2 => player_state_in("cave")
      }
    )

    with_deterministic_rand(42) do
      ClassicGame::TurnManager.enter_combat_mode(game, "cave", "goblin")
    end

    ClassicGame::TurnManager.remove_from_combat(game, 1)

    order = game.turn_state["combat_turn_order"]
    player_entries = order.select { |c| c["type"] == "player" }
    assert_equal 1, player_entries.length, "only player 2 should remain"
    assert_equal "2", player_entries.first["id"]
  end

  test "exit_combat_mode clears state and waiting flags" do
    ps2 = player_state_in("cave", waiting_for_combat_end: true)

    game = build_multiplayer_game(
      world_data: simple_world,
      players: {
        1 => player_state_in("cave"),
        2 => ps2
      }
    )

    with_deterministic_rand(42) do
      ClassicGame::TurnManager.enter_combat_mode(game, "cave", "goblin")
    end

    ClassicGame::TurnManager.exit_combat_mode(game)

    assert_nil game.turn_state["combat_turn_order"], "combat_turn_order should be cleared"
    assert_nil game.turn_state["combat_current_index"], "combat_current_index should be cleared"

    state2 = game.player_state(2)
    assert_not state2["waiting_for_combat_end"], "waiting_for_combat_end should be cleared for player 2"
  end
end
