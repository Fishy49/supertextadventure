# frozen_string_literal: true

require "test_helper"

class MultiplayerIntegrationTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_1 = 1
  USER_2 = 2

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern",
          "description" => "A cozy inn.",
          "exits" => { "north" => "library" }
        },
        "library" => {
          "name" => "The Library",
          "description" => "Books everywhere.",
          "exits" => { "south" => "tavern" }
        }
      },
      items: {
        "sword" => { "name" => "Sword", "keywords" => ["sword"] }
      }
    )

    @game_users = [
      FakeGameUser.new(USER_1, "Gandalf"),
      FakeGameUser.new(USER_2, "Aragorn")
    ]
  end

  # ─── Turn enforcement ─────────────────────────────────────────────────────

  test "player 2 cannot act on player 1s turn" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      game_users: @game_users
    )

    result = engine_execute(game, USER_2, "look")

    assert_not result[:success]
    assert_match(/turn/i, result[:response])
  end

  test "player 1 can act on their own turn" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      game_users: @game_users
    )

    result = engine_execute(game, USER_1, "look")

    assert result[:success]
  end

  test "turn advances to next player after command" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      game_users: @game_users
    )

    engine_execute(game, USER_1, "look")

    assert_equal "2", ClassicGame::TurnManager.current_player(game)
  end

  test "turn wraps around after both players act" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      game_users: @game_users
    )

    engine_execute(game, USER_1, "look")
    engine_execute(game, USER_2, "look")

    assert_equal "1", ClassicGame::TurnManager.current_player(game)
  end

  # ─── Room presence notifications ─────────────────────────────────────────

  test "entering a room with another player shows also-here line" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("library"),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    engine_execute(game, USER_1, "look") # advance turn to USER_2
    result = engine_execute(game, USER_2, "go north")

    assert result[:success]
    assert_match(/Also here/i, result[:response])
    assert_match(/Gandalf/i, result[:response])
  end

  test "entering a room triggers arrival secondary message for existing occupants" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("library"),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    engine_execute(game, USER_1, "look") # advance turn to USER_2
    result = engine_execute(game, USER_2, "go north")

    secondary = result[:secondary_messages] || []
    arrival_msg = secondary.find { |m| m[:text]&.match?(/arrived/i) }
    assert arrival_msg, "Expected arrival secondary message"
    assert_equal [USER_1.to_s], arrival_msg[:visible_to]
    assert_match(/Aragorn/i, arrival_msg[:text])
  end

  test "leaving a room triggers departure secondary message for remaining occupants" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern"),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = engine_execute(game, USER_1, "go north")

    secondary = result[:secondary_messages] || []
    departure_msg = secondary.find { |m| m[:text]&.match?(/left/i) }
    assert departure_msg, "Expected departure secondary message"
    assert_equal [USER_2.to_s], departure_msg[:visible_to]
    assert_match(/Gandalf/i, departure_msg[:text])
  end

  # ─── Single player mode (no turn state) ──────────────────────────────────

  test "single player game always allows acting" do
    game = build_game(world_data: @world, player_id: USER_1)

    result = engine_execute(game, USER_1, "look")

    assert result[:success]
  end

  # ─── Fled player waiting ──────────────────────────────────────────────────

  test "fled player is marked as waiting for combat end" do
    world_with_creature = build_world(
      starting_room: "arena",
      rooms: {
        "arena" => {
          "name" => "Arena",
          "description" => "A fighting pit.",
          "exits" => {}
        }
      },
      creatures: {
        "goblin" => {
          "name" => "Goblin",
          "health" => 10,
          "attack" => 3,
          "defense" => 0,
          "keywords" => ["goblin"]
        }
      }
    )

    combat_state = {
      "active" => true,
      "creature_id" => "goblin",
      "creature_health" => 5,
      "creature_max_health" => 10,
      "round_number" => 2,
      "defending" => false,
      "turn_order" => "player"
    }

    game = build_multiplayer_game(
      world_data: world_with_creature,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("arena", combat: combat_state),
        USER_2 => player_state_in("arena")
      },
      game_users: @game_users
    )

    # rand(1..100) > 50 fails the flee; returning 1 means flee succeeds
    handler = ClassicGame::Handlers::CombatHandler.new(game: game, user_id: USER_1)
    handler.define_singleton_method(:rand) { |*_args| 1 }
    command = ClassicGame::CommandParser.parse("flee")
    handler.handle(command)

    assert game.player_waiting_for_combat?(USER_1)
  end

  private

    def engine_execute(game, user_id, command_text)
      user = FakeUser.new(user_id)
      ClassicGame::Engine.execute(game: game, user: user, command_text: command_text)
    end
end
