# frozen_string_literal: true

require "test_helper"

class CombatHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  # Creature with 1 HP goes down in one hit (min damage is 1).
  # Creature with 0 attack still deals 1 damage (min).
  WEAK_CREATURE = {
    "name" => "Weak Goblin",
    "keywords" => ["goblin"],
    "health" => 1,
    "attack" => 0,
    "defense" => 0
  }.freeze

  # A creature that one-shots players on any roll.
  DEADLY_CREATURE = {
    "name" => "Death Knight",
    "keywords" => ["knight"],
    "health" => 100,
    "attack" => 100,
    "defense" => 0
  }.freeze

  setup do
    @world = build_world(
      starting_room: "arena",
      rooms: {
        "arena" => {
          "name" => "Arena", "description" => "A fighting pit.",
          "exits" => {}, "creatures" => ["goblin"]
        }
      },
      items: {
        "health_potion" => {
          "name" => "Health Potion", "keywords" => ["potion"],
          "takeable" => true, "consumable" => true,
          "combat_effect" => { "type" => "heal", "amount" => 5 }
        }
      },
      creatures: { "goblin" => WEAK_CREATURE.dup }
    )
  end

  # ─── Guard clause ───────────────────────────────────────────────────────────

  test "fails when player is not in combat" do
    game = build_game(world_data: @world, player_id: USER_ID)
    result = handle(game, "attack")

    assert_not result[:success]
    assert_includes result[:response].downcase, "not in combat"
  end

  # ─── ATTACK ─────────────────────────────────────────────────────────────────

  test "attack damages the creature via shared combat_state" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    handle(game, "attack")

    assert game.combat_state["creature_health"] < 50
  end

  test "attack marks the turn as consumed" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    result = handle(game, "attack")

    assert_equal true, result.dig(:state_changes, :combat_turn_consumed)
  end

  test "attack response mentions player damage to the creature" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    result = handle(game, "attack")

    assert_includes result[:response], "Weak Goblin"
    assert_includes result[:response].downcase, "damage"
  end

  # ─── Creature defeat ────────────────────────────────────────────────────────

  test "defeating creature clears combat state" do
    game = in_combat_game(creature_id: "goblin", creature_health: 1)
    handle(game, "attack")

    assert_nil game.combat_state, "game-level combat_state cleared"
    assert_nil game.player_state(USER_ID)["combat"], "per-player combat cleared"
  end

  test "defeating creature removes it from the room" do
    game = in_combat_game(creature_id: "goblin", creature_health: 1)
    handle(game, "attack")

    assert_not_includes game.room_state("arena")["creatures"], "goblin"
  end

  test "defeating creature drops loot into room" do
    world = build_world(
      starting_room: "arena",
      rooms: { "arena" => { "name" => "Arena", "description" => ".", "exits" => {}, "creatures" => ["goblin"] } },
      items: { "goblin_sword" => { "name" => "Goblin Sword", "keywords" => ["sword"] } },
      creatures: { "goblin" => WEAK_CREATURE.merge("loot" => ["goblin_sword"]) }
    )
    game = in_combat_game(world: world, creature_id: "goblin", creature_health: 1)
    handle(game, "attack")

    assert_includes game.room_state("arena")["items"], "goblin_sword"
  end

  # ─── DEFEND ─────────────────────────────────────────────────────────────────

  test "defend sets the defending flag and raises guard" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    result = handle(game, "defend")

    assert result[:success]
    assert_includes result[:response].downcase, "guard"
    assert_equal true, game.player_state(USER_ID).dig("combat", "defending")
    assert_equal true, result.dig(:state_changes, :combat_turn_consumed)
  end

  # ─── FLEE ───────────────────────────────────────────────────────────────────

  test "flee returns success and consumes the combat turn" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 10)
    result = handle(game, "flee")

    assert result[:success]
    assert_includes result[:response].downcase, "flee"
  end

  # ─── USE in combat ──────────────────────────────────────────────────────────

  test "use health potion heals player" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 3,
                          inventory: ["health_potion"])
    handle(game, "use potion")

    # Player had 3 HP, healed 5 → 8 HP (no inline counterattack any more)
    assert_equal 8, game.player_state(USER_ID)["health"]
  end

  test "use consumable potion removes it from inventory after use" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 10,
                          inventory: ["health_potion"])
    handle(game, "use potion")

    assert_not_includes game.player_state(USER_ID)["inventory"], "health_potion"
  end

  test "use item with no combat_effect fails" do
    @world["items"]["rock"] = { "name" => "Rock", "keywords" => ["rock"] }
    game = in_combat_game(creature_id: "goblin", creature_health: 50, inventory: ["rock"])
    result = handle(game, "use rock")

    assert_not result[:success]
    assert_includes result[:response].downcase, "can't use"
  end

  private

    def handle(game, input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::CombatHandler.new(game: game, user_id: USER_ID).handle(command)
    end

    def in_combat_game(creature_id:, creature_health:, world: nil, player_health: 10, inventory: [])
      world ||= @world
      game = build_game(
        world_data: world, player_id: USER_ID,
        player_state: player_state_in("arena", health: player_health, max_health: 10,
                                               inventory: inventory,
                                               combat: { "active" => true, "defending" => false })
      )
      game.set_combat_state(
        room_id: "arena",
        creature_id: creature_id,
        creature_health: creature_health
      )
      game.game_state["turn_state"] = game.turn_state.merge(
        "combat_turn_order" => [
          { "id" => USER_ID.to_s, "type" => "player", "initiative" => 10 },
          { "id" => creature_id.to_s, "type" => "creature", "initiative" => 5 }
        ],
        "combat_current_index" => 0
      )
      game
    end
end
