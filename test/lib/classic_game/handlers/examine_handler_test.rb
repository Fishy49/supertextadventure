# frozen_string_literal: true

require "test_helper"

class ExamineHandlerTest < ActiveSupport::TestCase
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
          "items" => ["sword"]
        }
      },
      items: {
        "sword" => {
          "name" => "Iron Sword", "keywords" => %w[sword iron],
          "takeable" => true, "weapon_damage" => 3,
          "description" => "A sharp iron sword."
        },
        "shield" => {
          "name" => "Wooden Shield", "keywords" => ["shield"],
          "takeable" => true, "defense_bonus" => 2,
          "description" => "A sturdy wooden shield."
        },
        "health_potion" => {
          "name" => "Health Potion", "keywords" => %w[potion health],
          "takeable" => true, "consumable" => true,
          "description" => "A red potion.",
          "combat_effect" => { "type" => "heal", "amount" => 5 }
        }
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID)
  end

  # ─── INVENTORY ───────────────────────────────────────────────────────────────

  test "inventory displays formatted header" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "=== INVENTORY ==="
    assert_includes result[:response], "Iron Sword"
  end

  test "inventory shows item count" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: %w[sword shield])
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "(2 items)"
  end

  test "inventory shows singular item count" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], "(1 item)"
  end

  test "inventory includes examine hint" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], "EXAMINE"
  end

  test "empty inventory shows carrying nothing" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: [])
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "You are carrying nothing."
  end

  # ─── EXAMINE INVENTORY ITEMS ─────────────────────────────────────────────────

  test "examining inventory item shows ASCII art" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("examine sword")

    assert result[:success]
    assert result[:response].include?("\n"), "response should be multi-line with ASCII art"
  end

  test "examining inventory item shows item name header" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("examine sword")

    assert_includes result[:response], "Iron Sword"
  end

  test "examining inventory item shows weapon stats" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("examine sword")

    assert result[:success]
    assert_includes result[:response], "Damage: +3"
  end

  test "examining inventory potion shows consumable" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["health_potion"])
    result = execute("examine potion")

    assert result[:success]
    assert_includes result[:response], "Consumable"
  end

  test "examining inventory potion shows heal amount" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["health_potion"])
    result = execute("examine potion")

    assert result[:success]
    assert_includes result[:response], "Heals 5 HP"
  end

  test "examining inventory armor shows defense stats" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["shield"])
    result = execute("examine shield")

    assert result[:success]
    assert_includes result[:response], "Defense: +2"
  end

  # ─── EXAMINE ROOM ITEMS ───────────────────────────────────────────────────────

  test "examining room item does not show stats" do
    # sword is in room items but NOT in inventory
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: [])
    result = execute("examine sword")

    assert result[:success]
    assert_includes result[:response], "A sharp iron sword."
    assert_not_includes result[:response], "Damage:"
  end

  test "examining room item shows plain description" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: [])
    result = execute("examine sword")

    assert result[:success]
    assert_includes result[:response], "A sharp iron sword."
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
