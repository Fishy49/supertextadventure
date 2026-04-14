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

  # ─── INVENTORY DATA IN STATE_CHANGES ─────────────────────────────────────────

  test "inventory result includes inventory_data in state_changes" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert result[:success]
    assert result[:state_changes].key?(:inventory_data), "inventory_data should be present in state_changes"
    assert_equal 1, result[:state_changes][:inventory_data].length
    assert_equal "Iron Sword", result[:state_changes][:inventory_data][0]["name"]
  end

  test "inventory_data includes item category" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_equal "weapon", result[:state_changes][:inventory_data][0]["category"]
  end

  test "inventory_data includes art_line" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert result[:state_changes][:inventory_data][0]["art_line"].present?,
           "art_line should be a non-empty string"
  end

  test "inventory_data includes item_id" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_equal "sword", result[:state_changes][:inventory_data][0]["item_id"]
  end

  test "empty inventory has no inventory_data" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: [])
    result = execute("inventory")

    assert result[:success]
    assert_empty result[:state_changes], "state_changes should be empty for empty inventory"
    assert_not result[:state_changes].key?(:inventory_data)
  end

  test "examining inventory item shows bordered output" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("examine sword")

    assert result[:success]
    assert_includes result[:response], "---", "response should include border characters"
    assert result[:response].include?("\n"), "response should be multi-line"
  end

  test "inventory works for different user_ids (multiplayer isolation)" do
    user2_id = 2
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    @game.game_state["player_states"][user2_id.to_s] = player_state_in("room1", inventory: ["shield"])

    result1 = ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID)
      .handle(ClassicGame::CommandParser.parse("inventory"))
    result2 = ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: user2_id)
      .handle(ClassicGame::CommandParser.parse("inventory"))

    items1 = result1[:state_changes][:inventory_data].pluck("name")
    items2 = result2[:state_changes][:inventory_data].pluck("name")

    assert_includes items1, "Iron Sword"
    assert_not_includes items1, "Wooden Shield"

    assert_includes items2, "Wooden Shield"
    assert_not_includes items2, "Iron Sword"
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
