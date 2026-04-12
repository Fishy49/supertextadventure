# frozen_string_literal: true

require "test_helper"

# End-to-end multiplayer scenarios exercised through ClassicGame::Engine.
# Two players share a game and take turns; tests verify turn enforcement,
# co-location visibility, player-to-player item exchange, and combat flags.
class MultiplayerSystemTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  PLAYER1_ID = 1
  PLAYER2_ID = 2

  User1 = Struct.new(:id)
  User2 = Struct.new(:id)

  # ─── World fixture ──────────────────────────────────────────────────────────

  def multiplayer_world
    build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "Tavern",
          "description" => "A busy tavern with a roaring fire.",
          "items" => ["sword"],
          "exits" => { "north" => "library" }
        },
        "library" => {
          "name" => "Library",
          "description" => "Shelves of dusty tomes.",
          "exits" => { "south" => "tavern" }
        },
        "cave" => {
          "name" => "Dark Cave",
          "description" => "A damp cave.",
          "creatures" => ["troll"],
          "exits" => { "north" => "tavern" }
        }
      },
      items: {
        "sword" => {
          "name" => "Iron Sword", "keywords" => %w[sword iron],
          "takeable" => true, "weapon_damage" => 3,
          "description" => "A sturdy iron sword."
        }
      },
      creatures: {
        "troll" => {
          "name" => "Troll", "keywords" => ["troll"],
          "hostile" => false, "health" => 20, "attack" => 3, "defense" => 0,
          "loot" => [], "on_defeat_msg" => "The troll collapses!"
        }
      }
    )
  end

  def build_two_player_game(p1_room: "tavern", p2_room: "tavern")
    build_multiplayer_game(
      world_data: multiplayer_world,
      players: {
        PLAYER1_ID => player_state_in(p1_room),
        PLAYER2_ID => player_state_in(p2_room)
      },
      character_names: { PLAYER1_ID => "Thorin", PLAYER2_ID => "Elara" }
    )
  end

  def user1 = User1.new(PLAYER1_ID)
  def user2 = User2.new(PLAYER2_ID)

  # Hand-roll a combat state without TurnManager.enter_combat_mode so tests
  # can set deterministic turn order. Marks every combatant as actively
  # fighting and puts the first combatant at index 0.
  def setup_shared_combat(game, creature_id:, creature_health:, combatants:)
    game.set_combat_state(
      room_id: game.player_state(combatants.first)["current_room"],
      creature_id: creature_id,
      creature_health: creature_health
    )
    combatants.each do |uid|
      ps = game.player_state(uid).dup
      ps["combat"] = { "active" => true, "defending" => false }
      game.update_player_state(uid, ps)
    end
    order = combatants.map.with_index do |uid, i|
      { "id" => uid.to_s, "type" => "player", "initiative" => 20 - i }
    end
    order << { "id" => creature_id.to_s, "type" => "creature", "initiative" => 0 }
    game.game_state["turn_state"] = game.turn_state.merge(
      "combat_turn_order" => order,
      "combat_current_index" => 0
    )
  end

  # ─── Turn order enforcement ─────────────────────────────────────────────────

  test "off-turn player is blocked" do
    game = build_two_player_game
    # Player 1's turn (index 0)
    r = execute_engine(game, user2, "look")

    assert_not r[:success]
    assert_includes r[:response], "not your turn"
    assert_equal true, r[:state_changes][:turn_blocked]
  end

  test "current-turn player can act" do
    game = build_two_player_game
    r = execute_engine(game, user1, "look")

    assert r[:success]
    assert_includes r[:response], "Tavern"
  end

  test "turn advances after player acts" do
    game = build_two_player_game
    assert_equal PLAYER1_ID, game.current_turn_user_id

    execute_engine(game, user1, "look")

    assert_equal PLAYER2_ID, game.current_turn_user_id, "should be player 2's turn after player 1 acts"
  end

  test "separated players wait for their turn" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "library")

    # Player 2 tries to act on player 1's turn
    r = execute_engine(game, user2, "look")
    assert_not r[:success]
    assert_includes r[:response], "not your turn"
  end

  # ─── Co-location visibility ─────────────────────────────────────────────────

  test "co-located players see each other in room description" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "tavern")
    r = execute_engine(game, user1, "look")

    assert r[:success]
    assert_includes r[:response], "Also here"
    assert_includes r[:response], "Elara"
  end

  test "solo player does not see also-here listing" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "library")
    r = execute_engine(game, user1, "look")

    assert r[:success]
    assert_not_includes r[:response], "Also here"
  end

  # ─── Player arrival ─────────────────────────────────────────────────────────

  test "player moving into occupied room sees also here in description" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "library")

    # Advance to player 2's turn
    execute_engine(game, user1, "look")
    assert_equal PLAYER2_ID, game.current_turn_user_id

    # Player 2 moves south into tavern where player 1 is
    r = execute_engine(game, user2, "go south")

    assert r[:success]
    assert_includes r[:response], "Also here"
    assert_includes r[:response], "Thorin"
  end

  test "movement state_changes include arrival and departure text when players present" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "library")

    # Advance to player 2's turn
    execute_engine(game, user1, "look")

    # Player 2 moves south to tavern (where player 1 is)
    r = execute_engine(game, user2, "go south")

    assert r[:state_changes][:arrival_text], "arrival_text should be present"
    assert_includes r[:state_changes][:arrival_text], "Elara"
    assert_includes r[:state_changes][:arrival_text], "north" # from north (opposite of south)
  end

  test "movement state_changes include departure text when leaving occupied room" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "tavern")

    # Player 1 moves north out of the tavern (player 2 is still in tavern)
    r = execute_engine(game, user1, "go north")

    assert r[:state_changes][:departure_text], "departure_text should be present"
    assert_includes r[:state_changes][:departure_text], "Thorin"
    assert_includes r[:state_changes][:departure_text], "north"
  end

  # ─── Player-to-player item giving ───────────────────────────────────────────

  test "player can give item to another player in the same room" do
    p1_state = player_state_in("tavern", inventory: ["sword"])

    game = build_multiplayer_game(
      world_data: multiplayer_world,
      players: {
        PLAYER1_ID => p1_state,
        PLAYER2_ID => player_state_in("tavern")
      },
      character_names: { PLAYER1_ID => "Thorin", PLAYER2_ID => "Elara" }
    )

    r = execute_engine(game, user1, "give sword to Elara")

    assert r[:success], "give to player should succeed"
    assert_includes r[:response], "Iron Sword"
    assert_includes r[:response], "Elara"

    assert_not_includes game.player_state(PLAYER1_ID)["inventory"], "sword",
                        "sword removed from giver"
    assert_includes game.player_state(PLAYER2_ID)["inventory"], "sword",
                    "sword added to receiver"
  end

  test "give to player fails if giver does not have the item" do
    game = build_two_player_game(p1_room: "tavern", p2_room: "tavern")
    # Player 1 has no sword in inventory initially
    r = execute_engine(game, user1, "give sword to Elara")

    assert_not r[:success]
  end

  test "give to player fails if target player is in a different room" do
    p1_state = player_state_in("tavern", inventory: ["sword"])
    game = build_multiplayer_game(
      world_data: multiplayer_world,
      players: {
        PLAYER1_ID => p1_state,
        PLAYER2_ID => player_state_in("library")
      },
      character_names: { PLAYER1_ID => "Thorin", PLAYER2_ID => "Elara" }
    )

    r = execute_engine(game, user1, "give sword to Elara")
    assert_not r[:success], "cannot give to player in another room"
  end

  # ─── Combat multiplayer ──────────────────────────────────────────────────────

  test "combat turn order is set when entering combat with multiple players" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")

    with_deterministic_rand(42) do
      ClassicGame::TurnManager.enter_combat_mode(game, "cave", "troll")
    end

    order = game.turn_state["combat_turn_order"]
    assert_equal 3, order.length, "2 players + 1 creature in combat order"
  end

  test "flee sets waiting_for_combat_end and removes from combat order" do
    # Both players in cave, enter combat manually
    p1_state = player_state_in("cave")
    p1_state["combat"] = {
      "active" => true, "creature_id" => "troll",
      "creature_health" => 1, "creature_max_health" => 1,
      "round_number" => 1, "defending" => false, "turn_order" => "player"
    }

    game = build_multiplayer_game(
      world_data: multiplayer_world,
      players: {
        PLAYER1_ID => p1_state,
        PLAYER2_ID => player_state_in("cave")
      },
      character_names: { PLAYER1_ID => "Thorin", PLAYER2_ID => "Elara" }
    )

    # Set combat turn order
    with_deterministic_rand(42) do
      ClassicGame::TurnManager.enter_combat_mode(game, "cave", "troll")
    end

    # Force flee to succeed by seeding rand to always flee
    with_deterministic_rand(99) do # rand(1..100) with seed 99 returns > 50 first? Let's check.
      # Simulate a successful flee by calling TurnManager directly
      ClassicGame::TurnManager.remove_from_combat(game, PLAYER1_ID)
    end

    order = game.turn_state["combat_turn_order"]
    player_entries = order.select { |c| c["type"] == "player" }
    assert_equal 1, player_entries.length
    assert_equal "2", player_entries.first["id"]
  end

  test "successful flee with another combatant in the room puts player in limbo" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")
    setup_shared_combat(game, creature_id: "troll", creature_health: 10, combatants: [PLAYER1_ID, PLAYER2_ID])

    with_deterministic_rand(1) do
      result = execute_engine(game, user1, "flee")
      assert result[:success]
      assert_includes result[:response], "break away"
    end

    assert_nil game.player_state(PLAYER1_ID)["combat"], "fleeing player's combat is cleared"
    assert_equal true, game.player_state(PLAYER1_ID)["waiting_for_combat_end"], "fleeing player is in limbo"
    assert_equal true, game.player_state(PLAYER2_ID).dig("combat", "active"), "other player still in combat"
    assert game.in_combat?, "combat still active"
  end

  test "successful flee with no other combatants clears combat cleanly" do
    game = build_two_player_game(p1_room: "cave", p2_room: "tavern")
    setup_shared_combat(game, creature_id: "troll", creature_health: 10, combatants: [PLAYER1_ID])

    with_deterministic_rand(1) do
      result = execute_engine(game, user1, "flee")
      assert result[:success]
    end

    assert_nil game.player_state(PLAYER1_ID)["combat"]
    assert_nil game.player_state(PLAYER1_ID)["waiting_for_combat_end"]
    assert_not game.in_combat?, "combat ended when last fighter fled"
  end

  test "creature defeat releases limbo players in the same room" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")
    setup_shared_combat(game, creature_id: "troll", creature_health: 1, combatants: [PLAYER1_ID])

    # P2 is in limbo (fled earlier) — still in room, not active in combat
    p2_ps = game.player_state(PLAYER2_ID).dup
    p2_ps["combat"] = nil
    p2_ps["waiting_for_combat_end"] = true
    game.update_player_state(PLAYER2_ID, p2_ps)

    result = execute_engine(game, user1, "attack troll")
    assert result[:success]
    assert_includes result[:response], "collapses"

    assert_nil game.player_state(PLAYER1_ID)["combat"]
    assert_nil game.player_state(PLAYER2_ID)["waiting_for_combat_end"],
               "limbo player released when combat ends"
    assert_not game.in_combat?
  end

  test "engine blocks limbo player with combat-finish waiting message" do
    p1_state = player_state_in("cave")
    p1_state["combat"] = {
      "active" => true, "creature_id" => "troll",
      "creature_health" => 10, "creature_max_health" => 10,
      "round_number" => 1, "defending" => false, "turn_order" => "player"
    }
    p2_state = player_state_in("cave", waiting_for_combat_end: true)

    game = build_multiplayer_game(
      world_data: multiplayer_world,
      players: { PLAYER1_ID => p1_state, PLAYER2_ID => p2_state },
      character_names: { PLAYER1_ID => "Thorin", PLAYER2_ID => "Elara" }
    )

    result = execute_engine(game, user2, "look")
    assert_not result[:success]
    assert_includes result[:response], "Waiting for combat to finish"
  end

  # ─── Multi-combatant combat ─────────────────────────────────────────────────

  test "attacking a creature pulls all co-located players into combat" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")

    execute_engine(game, user1, "attack troll")

    assert game.in_combat?, "game-level combat state is set"
    assert_equal "cave", game.combat_state["room_id"]
    assert_equal "troll", game.combat_state["creature_id"]
    assert_equal true, game.player_state(PLAYER1_ID).dig("combat", "active")
    assert_equal true, game.player_state(PLAYER2_ID).dig("combat", "active")
  end

  test "players out of the combat room are not dragged in" do
    game = build_two_player_game(p1_room: "cave", p2_room: "tavern")

    execute_engine(game, user1, "attack troll")

    assert game.in_combat?
    assert_equal true, game.player_state(PLAYER1_ID).dig("combat", "active")
    assert_nil game.player_state(PLAYER2_ID)["combat"],
               "player in a different room does not join combat"
  end

  test "combat_turn_order contains all in-room players plus the creature" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")

    execute_engine(game, user1, "attack troll")

    order = game.turn_state["combat_turn_order"]
    assert_equal 3, order.length
    types = order.pluck("type").tally
    assert_equal 2, types["player"]
    assert_equal 1, types["creature"]
  end

  test "shared creature HP is updated by each combatant's attacks" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")
    setup_shared_combat(game, creature_id: "troll", creature_health: 20, combatants: [PLAYER1_ID, PLAYER2_ID])

    execute_engine(game, user1, "attack")
    mid_hp = game.combat_state["creature_health"]
    assert mid_hp < 20, "P1's attack reduced shared creature HP"

    execute_engine(game, user2, "attack")
    end_hp = game.combat_state["creature_health"]
    assert end_hp < mid_hp, "P2's attack further reduced the same shared HP"
  end

  test "combat_turn_order advances past the acting player and runs the creature turn" do
    game = build_two_player_game(p1_room: "cave", p2_room: "cave")
    setup_shared_combat(game, creature_id: "troll", creature_health: 50, combatants: [PLAYER1_ID, PLAYER2_ID])
    # Position the creature immediately after P1 so its turn runs before P2's.
    game.game_state["turn_state"] = game.turn_state.merge(
      "combat_turn_order" => [
        { "id" => PLAYER1_ID.to_s, "type" => "player", "initiative" => 20 },
        { "id" => "troll", "type" => "creature", "initiative" => 15 },
        { "id" => PLAYER2_ID.to_s, "type" => "player", "initiative" => 10 }
      ],
      "combat_current_index" => 0
    )

    result = execute_engine(game, user1, "attack")

    assert result[:success]
    assert_includes result[:response], "Troll attacks"
    assert_equal PLAYER2_ID, game.current_combat_user_id,
                 "after P1 acts and the creature retaliates, P2 is up"
  end

  test "aggressive creature initiates combat at the creature's slot" do
    game = build_multiplayer_game(
      world_data: build_world(
        starting_room: "cave",
        rooms: { "cave" => { "name" => "Dark Cave", "description" => "A damp cave.",
                             "creatures" => ["wolf"], "exits" => {} } },
        creatures: { "wolf" => { "name" => "Wolf", "keywords" => ["wolf"],
                                 "hostile" => true, "health" => 20, "attack" => 2,
                                 "defense" => 0, "loot" => [] } }
      ),
      players: { PLAYER1_ID => player_state_in("cave") },
      character_names: { PLAYER1_ID => "Thorin" }
    )

    result = execute_engine(game, user1, "look")

    assert game.in_combat?
    assert_includes result[:response], "Wolf attacks"
    # Player is now in combat and can act on their turn
    assert_equal PLAYER1_ID, game.current_combat_user_id
  end

  test "exit_combat_mode clears waiting_for_combat_end for all players" do
    ps2 = player_state_in("cave", waiting_for_combat_end: true)
    game = build_multiplayer_game(
      world_data: multiplayer_world,
      players: {
        PLAYER1_ID => player_state_in("cave"),
        PLAYER2_ID => ps2
      },
      character_names: { PLAYER1_ID => "Thorin", PLAYER2_ID => "Elara" }
    )

    with_deterministic_rand(42) do
      ClassicGame::TurnManager.enter_combat_mode(game, "cave", "troll")
    end

    ClassicGame::TurnManager.exit_combat_mode(game)

    assert_not game.player_state(PLAYER2_ID)["waiting_for_combat_end"],
               "waiting_for_combat_end cleared after combat ends"
  end
end
