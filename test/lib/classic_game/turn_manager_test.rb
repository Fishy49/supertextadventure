# frozen_string_literal: true

require "test_helper"

class TurnManagerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  PLAYER_1 = 1
  PLAYER_2 = 2

  FakeUser = Struct.new(:id)

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern",
          "description" => "A cozy inn.",
          "exits" => {}
        }
      }
    )
  end

  # ─── can_act? ───────────────────────────────────────────────────────────────

  test "can_act? returns true when no turn state exists (single-player compat)" do
    game = build_game(world_data: @world, player_id: PLAYER_1)

    assert ClassicGame::TurnManager.can_act?(game, PLAYER_1)
  end

  test "can_act? returns true when it is player's turn" do
    game = multiplayer_game(current_turn: PLAYER_1)

    assert ClassicGame::TurnManager.can_act?(game, PLAYER_1)
  end

  test "can_act? returns false when it is not player's turn" do
    game = multiplayer_game(current_turn: PLAYER_1)

    assert_not ClassicGame::TurnManager.can_act?(game, PLAYER_2)
  end

  # ─── engine-level guard ─────────────────────────────────────────────────────

  test "engine rejects command when not player's turn" do
    game = multiplayer_game(current_turn: PLAYER_1)
    user2 = FakeUser.new(PLAYER_2)

    result = ClassicGame::Engine.execute(game: game, user: user2, command_text: "look")

    assert_not result[:success]
    assert_match(/Alice/, result[:response])
    assert_match(/turn/i, result[:response])
  end

  test "engine allows command when it is player's turn" do
    game = multiplayer_game(current_turn: PLAYER_1)
    user1 = FakeUser.new(PLAYER_1)

    result = ClassicGame::Engine.execute(game: game, user: user1, command_text: "look")

    assert result[:success]
    assert_includes result[:response], "Tavern"
  end

  # ─── advance_turn ───────────────────────────────────────────────────────────

  test "advance cycles to next player" do
    game = multiplayer_game(current_turn: PLAYER_1)

    ClassicGame::TurnManager.advance(game)

    assert_equal PLAYER_2.to_s, game.current_turn_user_id
  end

  test "advance wraps around to first player" do
    game = multiplayer_game(current_turn: PLAYER_2)

    ClassicGame::TurnManager.advance(game)

    assert_equal PLAYER_1.to_s, game.current_turn_user_id
  end

  test "advance with single player cycles back to same player" do
    game = build_game(world_data: @world, player_id: PLAYER_1)
    game.initialize_turn_order([PLAYER_1.to_s])

    ClassicGame::TurnManager.advance(game)

    assert_equal PLAYER_1.to_s, game.current_turn_user_id
  end

  # ─── waiting_message ────────────────────────────────────────────────────────

  test "waiting_message includes current player's name" do
    game = multiplayer_game(current_turn: PLAYER_1)

    msg = ClassicGame::TurnManager.waiting_message(game, PLAYER_2)

    assert_match(/Alice/, msg)
    assert_match(/turn/i, msg)
  end

  # ─── combat flee / end ──────────────────────────────────────────────────────

  test "handle_flee adds player to combat_waiting and advances turn" do
    game = multiplayer_game(current_turn: PLAYER_1)

    ClassicGame::TurnManager.handle_flee(game, PLAYER_1)

    assert_includes game.game_state["turn_state"]["combat_waiting"], PLAYER_1.to_s
    assert_equal PLAYER_2.to_s, game.current_turn_user_id
  end

  test "handle_combat_end clears combat_waiting list" do
    game = multiplayer_game(current_turn: PLAYER_2)
    game.player_fled_combat(PLAYER_1)

    ClassicGame::TurnManager.handle_combat_end(game)

    assert_empty game.game_state["turn_state"]["combat_waiting"]
  end

  test "advance skips players in combat_waiting" do
    game = multiplayer_game(current_turn: PLAYER_1)
    game.game_state["turn_state"]["combat_waiting"] = [PLAYER_2.to_s]

    ClassicGame::TurnManager.advance(game)

    # Player 2 is skipped; wraps back to player 1
    assert_equal PLAYER_1.to_s, game.current_turn_user_id
  end

  private

    def multiplayer_game(current_turn:)
      game = build_multiplayer_game(
        world_data: @world,
        players: {
          PLAYER_1 => player_state_in("tavern"),
          PLAYER_2 => player_state_in("tavern")
        }
      )
      game.initialize_turn_order([PLAYER_1.to_s, PLAYER_2.to_s])
      game.game_state["turn_state"]["current_user_id"] = current_turn.to_s
      game.game_state["player_names"] = {
        PLAYER_1.to_s => "Alice",
        PLAYER_2.to_s => "Bob"
      }
      game
    end
end
