# frozen_string_literal: true

require "test_helper"

class MovementProcessorTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  # ─── Helpers ──────────────────────────────────────────────────────────────────

  def build_patrol_world(stay_durations: [2, 1], unless_player_in: nil)
    movement = {
      "type" => "patrol",
      "route" => [
        { "room" => "tavern", "stay" => stay_durations[0] },
        { "room" => "storage_room", "stay" => stay_durations[1] }
      ]
    }
    movement["unless_player_in"] = unless_player_in if unless_player_in

    build_world(
      starting_room: "hallway",
      rooms: {
        "hallway" => {
          "name" => "Hallway", "description" => "A long hallway.",
          "exits" => { "north" => "tavern" }
        },
        "tavern" => {
          "name" => "The Tavern", "description" => "A cozy tavern.",
          "exits" => { "south" => "hallway", "east" => "storage_room" },
          "npcs" => ["barkeep"]
        },
        "storage_room" => {
          "name" => "Storage Room", "description" => "Dusty shelves.",
          "exits" => { "west" => "tavern" }
        }
      },
      npcs: {
        "barkeep" => {
          "name" => "Barkeep",
          "keywords" => ["barkeep"],
          "description" => "A burly bartender.",
          "movement" => movement
        }
      }
    )
  end

  def process(game)
    ClassicGame::MovementProcessor.process(game: game, user_id: USER_ID)
  end

  # ─── AC: Common DSL defines how NPCs and Creatures move ─────────────────────

  test "patrol NPC moves to next room after stay duration expires" do
    world = build_patrol_world(stay_durations: [2, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    # First call: counter goes to 1, stay is 2 — no move yet
    process(game)
    assert_includes game.room_state("tavern")["npcs"], "barkeep"

    # Second call: counter reaches 2 — move happens
    process(game)
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
  end

  test "patrol creature follows same DSL as NPC" do
    world = build_world(
      starting_room: "hallway",
      rooms: {
        "hallway" => {
          "name" => "Hallway", "description" => "A hallway.",
          "exits" => {}
        },
        "cave" => {
          "name" => "Cave", "description" => "A dark cave.",
          "exits" => { "east" => "tunnel" },
          "creatures" => ["bat"]
        },
        "tunnel" => {
          "name" => "Tunnel", "description" => "A narrow tunnel.",
          "exits" => { "west" => "cave" }
        }
      },
      creatures: {
        "bat" => {
          "name" => "Bat",
          "keywords" => ["bat"],
          "description" => "A screeching bat.",
          "health" => 2, "attack" => 1,
          "movement" => {
            "type" => "patrol",
            "route" => [
              { "room" => "cave", "stay" => 1 },
              { "room" => "tunnel", "stay" => 1 }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    process(game)

    assert_includes game.room_state("tunnel")["creatures"], "bat"
    assert_not_includes game.room_state("cave")["creatures"], "bat"
  end

  # ─── AC: Movement rules checked on every player command ─────────────────────

  test "Engine.execute triggers movement processing after command" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))
    user = OpenStruct.new(id: USER_ID)

    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
  end

  # ─── AC: Repetitive route movement ─────────────────────────────────────────

  test "patrol NPC cycles back to first stop after completing route" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    # Call 1: move from tavern (stop 0) to storage_room (stop 1)
    process(game)
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"

    # Call 2: move from storage_room (stop 1) back to tavern (stop 0)
    process(game)
    assert_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_not_includes game.room_state("storage_room")["npcs"], "barkeep"

    # Call 3: move from tavern (stop 0) to storage_room (stop 1) again
    process(game)
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
  end

  test "patrol NPC stays in room for correct number of ticks" do
    world = build_patrol_world(stay_durations: [3, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    # After 2 calls, NPC should still be in tavern (stay is 3)
    process(game)
    process(game)
    assert_includes game.room_state("tavern")["npcs"], "barkeep"

    # Third call triggers the move
    process(game)
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
  end

  # ─── AC: One-time triggered movement ───────────────────────────────────────

  test "triggered NPC does not move when flag is not set" do
    world = build_world(
      starting_room: "hallway",
      rooms: {
        "hallway" => {
          "name" => "Hallway", "description" => "A hallway.",
          "exits" => { "north" => "guard_room" }
        },
        "guard_room" => {
          "name" => "Guard Room", "description" => "A room with a guard.",
          "exits" => { "south" => "hallway", "east" => "dungeon" },
          "npcs" => ["guard"]
        },
        "dungeon" => {
          "name" => "Dungeon", "description" => "A dark dungeon.",
          "exits" => { "west" => "guard_room" }
        }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "keywords" => ["guard"],
          "description" => "A vigilant guard.",
          "movement" => {
            "type" => "triggered",
            "trigger_flag" => "alarm_raised",
            "destination" => "dungeon",
            "depart_text" => "The guard rushes out!",
            "arrive_text" => "A guard arrives, looking alarmed!"
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    process(game)

    assert_includes game.room_state("guard_room")["npcs"], "guard"
  end

  test "triggered NPC moves when flag is set" do
    world = build_world(
      starting_room: "hallway",
      rooms: {
        "hallway" => {
          "name" => "Hallway", "description" => "A hallway.",
          "exits" => { "north" => "guard_room" }
        },
        "guard_room" => {
          "name" => "Guard Room", "description" => "A room with a guard.",
          "exits" => { "south" => "hallway", "east" => "dungeon" },
          "npcs" => ["guard"]
        },
        "dungeon" => {
          "name" => "Dungeon", "description" => "A dark dungeon.",
          "exits" => { "west" => "guard_room" }
        }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "keywords" => ["guard"],
          "description" => "A vigilant guard.",
          "movement" => {
            "type" => "triggered",
            "trigger_flag" => "alarm_raised",
            "destination" => "dungeon",
            "depart_text" => "The guard rushes out!",
            "arrive_text" => "A guard arrives, looking alarmed!"
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))
    game.set_flag("alarm_raised", true)

    process(game)

    assert_not_includes game.room_state("guard_room")["npcs"], "guard"
    assert_includes game.room_state("dungeon")["npcs"], "guard"
  end

  test "triggered NPC moves only once even with repeated processing" do
    world = build_world(
      starting_room: "hallway",
      rooms: {
        "hallway" => {
          "name" => "Hallway", "description" => "A hallway.",
          "exits" => {}
        },
        "guard_room" => {
          "name" => "Guard Room", "description" => "A room with a guard.",
          "exits" => { "east" => "dungeon" },
          "npcs" => ["guard"]
        },
        "dungeon" => {
          "name" => "Dungeon", "description" => "A dark dungeon.",
          "exits" => { "west" => "guard_room" }
        }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "keywords" => ["guard"],
          "description" => "A vigilant guard.",
          "movement" => {
            "type" => "triggered",
            "trigger_flag" => "alarm_raised",
            "destination" => "dungeon"
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))
    game.set_flag("alarm_raised", true)

    process(game)
    process(game)

    assert_includes game.room_state("dungeon")["npcs"], "guard"
    state = game.movement_state("npc", "guard")
    assert state["triggered"]
  end

  # ─── AC: Player-location-aware movement ────────────────────────────────────

  test "patrol NPC skips move when player is in same room and unless_player_in matches" do
    world = build_patrol_world(stay_durations: [1, 1], unless_player_in: ["tavern"])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("tavern"))

    process(game)

    assert_includes game.room_state("tavern")["npcs"], "barkeep"
  end

  test "patrol NPC moves normally when player is not in restricted room" do
    world = build_patrol_world(stay_durations: [1, 1], unless_player_in: ["tavern"])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    process(game)

    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
  end

  # ─── Narration tests ──────────────────────────────────────────────────────

  test "returns depart narration when NPC leaves player's room" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("tavern"))

    messages = process(game)

    assert_includes messages, "Barkeep leaves."
  end

  test "returns arrive narration when NPC arrives in player's room" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("storage_room"))

    messages = process(game)

    assert_includes messages, "Barkeep arrives."
  end

  test "returns custom depart_text from movement definition" do
    movement = {
      "type" => "patrol",
      "route" => [
        { "room" => "tavern", "stay" => 1 },
        { "room" => "storage_room", "stay" => 1 }
      ],
      "depart_text" => "The barkeep heads to the back."
    }
    world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern", "description" => "A cozy tavern.",
          "exits" => { "east" => "storage_room" },
          "npcs" => ["barkeep"]
        },
        "storage_room" => {
          "name" => "Storage Room", "description" => "Dusty shelves.",
          "exits" => { "west" => "tavern" }
        }
      },
      npcs: {
        "barkeep" => {
          "name" => "Barkeep",
          "keywords" => ["barkeep"],
          "description" => "A burly bartender.",
          "movement" => movement
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("tavern"))

    messages = process(game)

    assert_includes messages, "The barkeep heads to the back."
  end

  test "returns nil narration when player cannot see the move" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    messages = process(game)

    assert_empty messages
  end

  # ─── Engine integration narration test ─────────────────────────────────────

  test "Engine.execute appends movement narration to command response" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("tavern"))
    user = OpenStruct.new(id: USER_ID)

    result = ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    assert_includes result[:response], "Barkeep leaves."
  end

  # ─── Validation tests ─────────────────────────────────────────────────────

  test "validate_world_data rejects NPC with unknown movement type" do
    world = build_world(
      rooms: { "room1" => { "name" => "Room", "description" => "A room.", "exits" => {} } },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => { "type" => "wander" }
        }
      }
    )

    errors = ClassicGame::Engine.validate_world_data(world)

    assert errors.any? { |e| e.include?("unknown movement type") }
  end

  test "validate_world_data rejects patrol with no route" do
    world = build_world(
      rooms: { "room1" => { "name" => "Room", "description" => "A room.", "exits" => {} } },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => { "type" => "patrol" }
        }
      }
    )

    errors = ClassicGame::Engine.validate_world_data(world)

    assert errors.any? { |e| e.include?("route") }
  end

  test "validate_world_data rejects triggered with no destination" do
    world = build_world(
      rooms: { "room1" => { "name" => "Room", "description" => "A room.", "exits" => {} } },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => { "type" => "triggered", "trigger_flag" => "alarm" }
        }
      }
    )

    errors = ClassicGame::Engine.validate_world_data(world)

    assert errors.any? { |e| e.include?("destination") }
  end
end
