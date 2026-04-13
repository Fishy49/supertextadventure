# frozen_string_literal: true

require "test_helper"

class InventoryHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  setup do
    @world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Test Room",
          "description" => "A plain room.",
          "exits" => {},
          "items" => []
        }
      },
      items: {
        "sword" => {
          "name" => "Iron Sword",
          "keywords" => %w[sword iron],
          "description" => "A sharp iron blade. It gleams in the light."
        },
        "shield" => {
          "name" => "Wooden Shield",
          "keywords" => ["shield"],
          "description" => "A sturdy wooden shield."
        },
        "mystery_item" => {
          "name" => "Strange Object",
          "keywords" => ["mystery"],
          "description" => "You have no idea what this is."
        },
        "rock" => {
          "name" => "Plain Rock",
          "keywords" => ["rock"]
        }
      },
      creatures: {
        "troll" => {
          "name" => "Cave Troll",
          "keywords" => ["troll"],
          "health" => 5,
          "max_health" => 5,
          "damage" => 2,
          "description" => "A fearsome troll."
        }
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID)
  end

  test "inventory when empty shows carrying nothing" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: [])
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "You are carrying nothing."
  end

  test "inventory shows decorated header" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "=== INVENTORY ==="
  end

  test "inventory shows item name for each item" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: %w[sword shield])
    result = execute("inventory")

    assert_includes result[:response], "Iron Sword"
    assert_includes result[:response], "Wooden Shield"
  end

  test "inventory shows ASCII art for items with matching keywords" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], ClassicGame::ItemArt::ART["sword"].split("\n").first
  end

  test "inventory shows item description" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], "A sharp iron blade."
  end

  test "inventory shows generic art for items without matching keywords" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["mystery_item"])
    result = execute("inventory")

    assert_includes result[:response], ClassicGame::ItemArt::GENERIC_ART.split("\n").first
  end

  test "inventory shows examine hint" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], "EXAMINE"
  end

  test "inventory shows fallback description for items without description" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["rock"])
    result = execute("inventory")

    assert_includes result[:response], "A mysterious item."
  end

  test "inventory shortcut i works" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("i")

    assert_includes result[:response], "=== INVENTORY ==="
    assert_includes result[:response], "Iron Sword"
  end

  test "inventory works during combat" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in(
      "room1",
      inventory: ["sword"],
      combat: {
        "active" => true,
        "creature_id" => "troll",
        "creature_health" => 5,
        "creature_max_health" => 5,
        "round_number" => 1,
        "defending" => false,
        "turn_order" => "player"
      }
    )
    command = ClassicGame::CommandParser.parse("inventory")
    result = ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "=== INVENTORY ==="
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
