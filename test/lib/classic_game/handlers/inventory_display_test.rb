# frozen_string_literal: true

require "test_helper"

class InventoryDisplayTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  setup do
    @world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Test Room",
          "description" => "A plain room.",
          "exits" => {}
        }
      },
      items: {
        "sword" => {
          "name" => "Iron Sword",
          "keywords" => %w[sword iron],
          "takeable" => true,
          "weapon_damage" => 3,
          "description" => "A razor-sharp iron sword. Forged in fire."
        },
        "shield" => {
          "name" => "Wooden Shield",
          "keywords" => %w[shield wooden],
          "takeable" => true,
          "defense_bonus" => 2,
          "description" => "A sturdy wooden shield."
        },
        "potion" => {
          "name" => "Health Potion",
          "keywords" => %w[potion health],
          "takeable" => true,
          "consumable" => true,
          "description" => "A red potion that restores health.",
          "combat_effect" => { "type" => "heal", "amount" => 5 }
        },
        "trinket" => {
          "name" => "Strange Trinket",
          "keywords" => %w[trinket strange],
          "takeable" => true,
          "description" => "A curious trinket of unknown origin."
        },
        "magic_orb" => {
          "name" => "Magic Orb",
          "keywords" => %w[orb magic],
          "takeable" => true,
          "art" => "<*>\n|X|\n<*>",
          "description" => "A glowing orb humming with power."
        },
        "crate" => {
          "name" => "Wooden Crate",
          "keywords" => %w[crate wooden],
          "is_container" => true,
          "starts_closed" => false,
          "contents" => []
        }
      }
    )
  end

  # ─── Test 1: Header and footer ──────────────────────────────────────────────

  test "inventory shows header and footer" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: %w[sword potion])
    )

    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "=== INVENTORY ==="
    assert_includes result[:response], "Iron Sword"
    assert_includes result[:response], "Health Potion"
    assert_includes result[:response], "EXAMINE"
  end

  # ─── Test 2: ASCII art for weapon ───────────────────────────────────────────

  test "inventory shows ASCII art for weapon" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: %w[sword potion])
    )

    result = execute("inventory")

    assert result[:success]
    # Weapon art contains the distinctive "|>" marker
    assert_includes result[:response], "|>"
  end

  # ─── Test 3: Item stats ──────────────────────────────────────────────────────

  test "inventory shows item stats" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: %w[sword shield potion])
    )

    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "(weapon +3)"
    assert_includes result[:response], "(defense +2)"
    assert_includes result[:response], "(consumable)"
  end

  # ─── Test 4: Condensed list on rapid repeat ──────────────────────────────────

  test "inventory shows condensed list on rapid repeat" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: %w[sword shield])
    )

    # First call — full display
    result1 = execute("inventory")
    assert result1[:success]
    assert_includes result1[:response], "=== INVENTORY ==="

    # Second call on the same turn (turn_count not incremented) — condensed
    result2 = execute("inventory")
    assert result2[:success]
    assert_includes result2[:response], "You are carrying:"
    assert_not_includes result2[:response], "=== INVENTORY ==="
  end

  # ─── Test 5: Empty inventory unchanged ───────────────────────────────────────

  test "empty inventory unchanged" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: [])
    )

    result = execute("inventory")

    assert result[:success]
    assert_equal "You are carrying nothing.", result[:response]
  end

  # ─── Test 6: Custom item art ─────────────────────────────────────────────────

  test "inventory with custom item art" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: ["magic_orb"])
    )

    result = execute("inventory")

    assert result[:success]
    assert_includes result[:response], "<*>"
  end

  # ─── Test 7: Inventory works during combat ────────────────────────────────────

  test "inventory works during combat" do
    combat_state = {
      "active" => true,
      "creature_id" => "troll",
      "creature_health" => 5,
      "creature_max_health" => 5,
      "moves" => 0
    }
    world_with_creature = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => { "name" => "Cave", "description" => "A cave.", "exits" => {} }
      },
      items: {
        "sword" => {
          "name" => "Iron Sword",
          "keywords" => %w[sword],
          "takeable" => true,
          "weapon_damage" => 3,
          "description" => "A sharp sword."
        }
      },
      creatures: {
        "troll" => {
          "name" => "Troll",
          "keywords" => ["troll"],
          "hostile" => true,
          "health" => 5,
          "attack" => 2,
          "defense" => 0
        }
      }
    )
    game = build_game(
      world_data: world_with_creature,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: ["sword"], combat: combat_state)
    )

    command = ClassicGame::CommandParser.parse("inventory")
    result = ClassicGame::Handlers::CombatHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "=== INVENTORY ==="
  end

  # ─── Test 8: Art fallback to default for unknown item ─────────────────────────

  test "inventory art fallback to default for unknown item" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: ["trinket"])
    )

    result = execute("inventory")

    assert result[:success]
    # Default art contains "| bag |"
    assert_includes result[:response], "| bag |"
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
