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
    assert_includes result[:response], "INVENTORY"
    assert(result[:response].include?("╔") || result[:response].include?("║"),
           "inventory should show box drawing characters")
    assert_includes result[:response], "Iron Sword"
  end

  test "inventory shows item count" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: %w[sword shield])
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "2 items"
  end

  test "inventory shows singular item count" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], "1 item"
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

  test "inventory shows weapon icon" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("inventory")

    assert_includes result[:response], "/|\\"
  end

  test "inventory shows multiple item icons" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: %w[sword health_potion])
    result = execute("inventory")

    assert_includes result[:response], "/|\\"
    assert_includes result[:response], "(*)"
    assert_includes result[:response], "2 items"
  end

  test "inventory anti-spam returns condensed response on rapid check" do
    state = player_state_in("room1", inventory: ["sword"]).merge("last_inventory_at" => Time.now.to_f)
    @game.game_state["player_states"][USER_ID.to_s] = state
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "You're carrying 1 item"
    assert_includes result[:response], "EXAMINE <item> for details"
    assert_not(result[:response].include?("╔") || result[:response].include?("╚"),
               "condensed response should not contain box borders")
  end

  test "inventory returns full box after cooldown" do
    state = player_state_in("room1", inventory: ["sword"]).merge("last_inventory_at" => Time.now.to_f - 3.0)
    @game.game_state["player_states"][USER_ID.to_s] = state
    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "INVENTORY"
    assert(result[:response].include?("╔") || result[:response].include?("║"),
           "full response should contain box drawing characters")
  end

  # ─── EXAMINE INVENTORY ITEMS ─────────────────────────────────────────────────

  test "examining inventory item shows framed output" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("examine sword")

    assert result[:success]
    assert(result[:response].include?("╔") || result[:response].include?("║"),
           "framed examine should show box drawing characters")
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

  test "examining inventory item shows description in framed output" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("examine sword")

    assert result[:success]
    assert_includes result[:response], "A sharp iron sword."
  end

  test "examining inventory potion shows framed consumable info" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["health_potion"])
    result = execute("examine potion")

    assert result[:success]
    assert(result[:response].include?("╔") || result[:response].include?("║"),
           "framed examine should show box drawing characters")
    assert_includes result[:response], "Health Potion"
    assert_includes result[:response], "Heals 5 HP"
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

  test "examining room item does not show box borders" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: [])
    result = execute("examine sword")

    assert result[:success]
    assert_not(result[:response].include?("╔") || result[:response].include?("╚"),
               "room item examine should not have box borders")
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
