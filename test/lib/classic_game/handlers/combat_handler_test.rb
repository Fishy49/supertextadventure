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

  test "attack damages the creature" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    handle(game, "attack")

    # creature_health should be less than 50 after the attack
    assert game.player_state(USER_ID).dig("combat", "creature_health") < 50
  end

  test "attack increments round number" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    initial_round = game.player_state(USER_ID).dig("combat", "round_number")
    handle(game, "attack")

    assert_equal initial_round + 1, game.player_state(USER_ID).dig("combat", "round_number")
  end

  test "attack response mentions player damage and creature retaliation" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    result = handle(game, "attack")

    assert_includes result[:response], "Weak Goblin"
    assert_includes result[:response].downcase, "damage"
  end

  # ─── Creature defeat ────────────────────────────────────────────────────────

  test "defeating creature clears combat state" do
    game = in_combat_game(creature_id: "goblin", creature_health: 1)
    handle(game, "attack")

    assert_nil game.player_state(USER_ID)["combat"]
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

  # ─── Player death ───────────────────────────────────────────────────────────

  test "player death returns game over message" do
    world = build_world(
      starting_room: "arena",
      rooms: { "arena" => { "name" => "Arena", "description" => ".", "exits" => {}, "creatures" => ["knight"] } },
      creatures: { "knight" => DEADLY_CREATURE.dup }
    )
    game = in_combat_game(world: world, creature_id: "knight", creature_health: 999, player_health: 1)
    result = handle(game, "attack")

    assert_not result[:success]
    assert_includes result[:response], "GAME OVER"
  end

  # ─── DEFEND ─────────────────────────────────────────────────────────────────

  test "defend response mentions blocking damage" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50)
    result = handle(game, "defend")

    assert result[:success]
    assert_includes result[:response].downcase, "guard"
  end

  test "defend still deals damage to player (but less than attack would)" do
    # With a 0-attack goblin, min damage is 1, so defend always takes exactly 1
    # (attack=0, randomness=-2..2 but capped at 1 minimum, player_defense=0, defending adds +3 so 0+(-2..2)-3 = always <=0 → capped at 1)
    # Actually: creature_attack(0) + rand(-2..2) - player_defense(0) - defending_bonus(3) -> floor at 1
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 10)
    handle(game, "defend")

    # Player should have taken at least 1 damage
    assert game.player_state(USER_ID)["health"] < 10
  end

  # ─── FLEE ───────────────────────────────────────────────────────────────────

  test "flee returns a success response regardless of outcome" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 10)
    result = handle(game, "flee")

    # Flee always returns success: even a failed flee attempt is a valid action
    # (player death would return failure, but goblin's 0-attack can't one-shot 10 HP)
    assert result[:success]
    assert_includes result[:response].downcase, "flee"
  end

  test "flee always produces a coherent game state" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 10)
    handle(game, "flee")

    combat = game.player_state(USER_ID)["combat"]
    health = game.player_state(USER_ID)["health"]

    # Either combat was cleared (successful flee) or health decreased (failed flee with damage)
    assert combat.nil? || health < 10,
           "Expected either combat cleared or health reduced, got combat=#{combat.inspect}, health=#{health}"
  end

  # ─── USE in combat ──────────────────────────────────────────────────────────

  test "use health potion heals player" do
    game = in_combat_game(creature_id: "goblin", creature_health: 50, player_health: 3,
                          inventory: ["health_potion"])
    handle(game, "use potion")

    # Health should be higher than 3 (even accounting for creature counterattack)
    # Player had 3 HP, healed 5 → 8 HP, then goblin deals at least 1 → at most 7
    assert game.player_state(USER_ID)["health"] > 3
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
      combat_state = {
        "active" => true,
        "creature_id" => creature_id,
        "creature_health" => creature_health,
        "creature_max_health" => creature_health,
        "round_number" => 1,
        "defending" => false
      }
      build_game(
        world_data: world, player_id: USER_ID,
        player_state: player_state_in("arena", health: player_health, max_health: 10,
                                               inventory: inventory, combat: combat_state)
      )
    end
end
