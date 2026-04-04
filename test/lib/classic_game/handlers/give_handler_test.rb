# frozen_string_literal: true

require "test_helper"

class GiveHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  PLAYER_1 = 1
  PLAYER_2 = 2

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern",
          "description" => "A cozy inn.",
          "exits" => { "east" => "market" }
        },
        "market" => {
          "name" => "The Market",
          "description" => "Busy stalls.",
          "exits" => { "west" => "tavern" }
        }
      },
      items: {
        "iron_sword" => {
          "name" => "Iron Sword",
          "keywords" => %w[sword iron],
          "takeable" => true
        },
        "potion" => {
          "name" => "Red Potion",
          "keywords" => %w[potion red],
          "takeable" => true
        }
      }
    )
  end

  # ─── successful give ─────────────────────────────────────────────────────────

  test "gives item from player 1 to player 2 in same room" do
    game = same_room_game(p1_inventory: ["iron_sword"])
    command = ClassicGame::CommandParser.parse("give sword to Bob")

    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert result[:success]
    assert_includes result[:response], "Iron Sword"
    assert_includes result[:response], "Bob"
    assert_not_includes game.player_state(PLAYER_1)["inventory"], "iron_sword"
    assert_includes game.player_state(PLAYER_2)["inventory"], "iron_sword"
  end

  test "response says 'You give the [item] to [player]'" do
    game = same_room_game(p1_inventory: ["iron_sword"])
    command = ClassicGame::CommandParser.parse("give sword to Bob")

    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_match(/You give the Iron Sword to Bob/, result[:response])
  end

  test "works with full item name" do
    game = same_room_game(p1_inventory: ["iron_sword"])
    command = ClassicGame::CommandParser.parse("give iron sword to Bob")

    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert result[:success]
  end

  # ─── failures ────────────────────────────────────────────────────────────────

  test "fails when item not in player inventory" do
    game = same_room_game(p1_inventory: [])
    command = ClassicGame::CommandParser.parse("give sword to Bob")

    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_not result[:success]
    assert_includes result[:response].downcase, "don't have"
  end

  test "fails when recipient player is in a different room" do
    game = build_multiplayer_game(
      world_data: @world,
      players: {
        PLAYER_1 => player_state_in("tavern", inventory: ["iron_sword"]),
        PLAYER_2 => player_state_in("market")
      }
    )
    game.game_state["player_names"] = { PLAYER_1.to_s => "Alice", PLAYER_2.to_s => "Bob" }

    command = ClassicGame::CommandParser.parse("give sword to Bob")
    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_not result[:success]
    assert_match(/don't see/i, result[:response])
  end

  test "fails when recipient player name not found" do
    game = same_room_game(p1_inventory: ["iron_sword"])
    command = ClassicGame::CommandParser.parse("give sword to Charlie")

    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_not result[:success]
  end

  test "fails when no item or recipient specified" do
    game = same_room_game(p1_inventory: [])
    command = ClassicGame::CommandParser.parse("give")

    result = ClassicGame::Handlers::GiveHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_not result[:success]
  end

  # ─── InteractHandler delegation ──────────────────────────────────────────────

  test "InteractHandler delegates give to player to GiveHandler" do
    game = same_room_game(p1_inventory: ["iron_sword"])
    command = ClassicGame::CommandParser.parse("give sword to Bob")

    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert result[:success]
    assert_includes game.player_state(PLAYER_2)["inventory"], "iron_sword"
  end

  private

    def same_room_game(p1_inventory: [])
      game = build_multiplayer_game(
        world_data: @world,
        players: {
          PLAYER_1 => player_state_in("tavern", inventory: p1_inventory),
          PLAYER_2 => player_state_in("tavern")
        }
      )
      game.game_state["player_names"] = {
        PLAYER_1.to_s => "Alice",
        PLAYER_2.to_s => "Bob"
      }
      game
    end
end
