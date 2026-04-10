# frozen_string_literal: true

require "test_helper"

class NpcMovementProcessorTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  # ─── Patrol tests ───────────────────────────────────────────────────────────

  test "patrol NPC moves to next room after duration expires" do
    world = build_world(
      starting_room: "room_a",
      rooms: {
        "room_a" => { "name" => "Room A", "description" => "Room A.", "npcs" => ["guard"], "exits" => { "east" => "room_b" } },
        "room_b" => { "name" => "Room B", "description" => "Room B.", "exits" => { "west" => "room_a" } }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "room_a", "duration" => 2 },
              { "room" => "room_b", "duration" => 2 }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("room_a"))

    3.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_not_includes game.room_state("room_a")["npcs"], "guard"
    assert_includes game.room_state("room_b")["npcs"], "guard"
  end

  test "patrol NPC cycles back to first room" do
    world = build_world(
      starting_room: "room_a",
      rooms: {
        "room_a" => { "name" => "Room A", "description" => "Room A.", "npcs" => ["guard"], "exits" => { "east" => "room_b" } },
        "room_b" => { "name" => "Room B", "description" => "Room B.", "exits" => { "west" => "room_a" } }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "room_a", "duration" => 2 },
              { "room" => "room_b", "duration" => 2 }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("room_c"))

    5.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes game.room_state("room_a")["npcs"], "guard"
    assert_not_includes game.room_state("room_b")["npcs"], "guard"
  end

  test "patrol NPC stays put when next step is blocked by player proximity" do
    world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => { "name" => "Tavern", "description" => "Tavern.", "npcs" => ["barkeep"], "exits" => { "east" => "storage" } },
        "storage" => { "name" => "Storage", "description" => "Storage.", "exits" => { "west" => "tavern" } },
        "other_room" => { "name" => "Other", "description" => "Other.", "exits" => {} }
      },
      npcs: {
        "barkeep" => {
          "name" => "Barkeep",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "tavern", "duration" => 2 },
              { "room" => "storage", "duration" => 2, "blocked_while_player_in" => ["tavern"] }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("tavern"))

    3.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_not_includes game.room_state("storage")["npcs"] || [], "barkeep"
  end

  test "patrol NPC moves once player leaves the blocking room" do
    world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => { "name" => "Tavern", "description" => "Tavern.", "npcs" => ["barkeep"], "exits" => { "east" => "storage" } },
        "storage" => { "name" => "Storage", "description" => "Storage.", "exits" => { "west" => "tavern" } },
        "other_room" => { "name" => "Other", "description" => "Other.", "exits" => {} }
      },
      npcs: {
        "barkeep" => {
          "name" => "Barkeep",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "tavern", "duration" => 2 },
              { "room" => "storage", "duration" => 2, "blocked_while_player_in" => ["tavern"] }
            ]
          }
        }
      }
    )
    ps = player_state_in("tavern")
    game = build_game(world_data: world, player_id: USER_ID, player_state: ps)

    3.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes game.room_state("tavern")["npcs"], "barkeep"

    # Move player out of tavern
    ps["current_room"] = "other_room"
    game.update_player_state(USER_ID, ps)

    ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID)

    assert_includes game.room_state("storage")["npcs"], "barkeep"
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
  end

  # ─── Triggered movement tests ───────────────────────────────────────────────

  test "triggered movement fires when flag is set" do
    world = build_world(
      starting_room: "hall",
      rooms: {
        "cave" => { "name" => "Cave", "description" => "Cave.", "creatures" => ["bat"], "exits" => { "east" => "hall" } },
        "hall" => { "name" => "Hall", "description" => "Hall.", "exits" => { "west" => "cave" } }
      },
      creatures: {
        "bat" => {
          "name" => "Bat",
          "movement" => {
            "type" => "triggered",
            "trigger_flag" => "alarm",
            "destination" => "hall"
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hall"))
    game.set_flag("alarm", true)

    ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID)

    assert_not_includes game.room_state("cave")["creatures"], "bat"
    assert_includes game.room_state("hall")["creatures"], "bat"
  end

  test "triggered movement only fires once" do
    world = build_world(
      starting_room: "hall",
      rooms: {
        "cave" => { "name" => "Cave", "description" => "Cave.", "creatures" => ["bat"], "exits" => { "east" => "hall" } },
        "hall" => { "name" => "Hall", "description" => "Hall.", "exits" => { "west" => "cave" } }
      },
      creatures: {
        "bat" => {
          "name" => "Bat",
          "movement" => {
            "type" => "triggered",
            "trigger_flag" => "alarm",
            "destination" => "hall"
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hall"))
    game.set_flag("alarm", true)

    2.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes game.room_state("hall")["creatures"], "bat"
    assert_not_includes game.room_state("cave")["creatures"] || [], "bat"
  end

  test "triggered movement does not fire when flag is not set" do
    world = build_world(
      starting_room: "hall",
      rooms: {
        "cave" => { "name" => "Cave", "description" => "Cave.", "creatures" => ["bat"], "exits" => { "east" => "hall" } },
        "hall" => { "name" => "Hall", "description" => "Hall.", "exits" => { "west" => "cave" } }
      },
      creatures: {
        "bat" => {
          "name" => "Bat",
          "movement" => {
            "type" => "triggered",
            "trigger_flag" => "alarm",
            "destination" => "hall"
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hall"))

    ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID)

    assert_includes game.room_state("cave")["creatures"], "bat"
    assert_not_includes game.room_state("hall")["creatures"] || [], "bat"
  end

  # ─── Message generation tests ────────────────────────────────────────────────

  test "departure message shown when NPC leaves player room" do
    world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => { "name" => "Tavern", "description" => "Tavern.", "npcs" => ["barkeep"], "exits" => { "east" => "storage" } },
        "storage" => { "name" => "Storage", "description" => "Storage.", "exits" => { "west" => "tavern" } }
      },
      npcs: {
        "barkeep" => {
          "name" => "Barkeep",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "tavern", "duration" => 2 },
              { "room" => "storage", "duration" => 2 }
            ],
            "depart_msg" => "The Barkeep heads to the back."
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("tavern"))

    messages = []
    3.times { messages = ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes messages, "The Barkeep heads to the back."
  end

  test "arrival message shown when NPC enters player room" do
    world = build_world(
      starting_room: "storage",
      rooms: {
        "tavern" => { "name" => "Tavern", "description" => "Tavern.", "npcs" => ["barkeep"], "exits" => { "east" => "storage" } },
        "storage" => { "name" => "Storage", "description" => "Storage.", "exits" => { "west" => "tavern" } }
      },
      npcs: {
        "barkeep" => {
          "name" => "Barkeep",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "tavern", "duration" => 2 },
              { "room" => "storage", "duration" => 2 }
            ],
            "arrive_msg" => "The Barkeep arrives."
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("storage"))

    messages = []
    3.times { messages = ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes messages, "The Barkeep arrives."
  end

  test "no message when NPC moves between rooms player is not in" do
    world = build_world(
      starting_room: "room_c",
      rooms: {
        "room_a" => { "name" => "Room A", "description" => "A.", "npcs" => ["guard"], "exits" => { "east" => "room_b" } },
        "room_b" => { "name" => "Room B", "description" => "B.", "exits" => { "west" => "room_a" } },
        "room_c" => { "name" => "Room C", "description" => "C.", "exits" => {} }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "room_a", "duration" => 2 },
              { "room" => "room_b", "duration" => 2 }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("room_c"))

    messages = []
    3.times { messages = ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_empty messages
  end

  test "default departure message used when custom messages not provided" do
    world = build_world(
      starting_room: "room_a",
      rooms: {
        "room_a" => { "name" => "Room A", "description" => "A.", "npcs" => ["guard"], "exits" => { "east" => "room_b" } },
        "room_b" => { "name" => "Room B", "description" => "B.", "exits" => { "west" => "room_a" } }
      },
      npcs: {
        "guard" => {
          "name" => "Guard",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "room_a", "duration" => 2 },
              { "room" => "room_b", "duration" => 2 }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("room_a"))

    messages = []
    3.times { messages = ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes messages, "The Guard leaves."
  end

  # ─── Combat exclusion test ───────────────────────────────────────────────────

  test "creature in active combat with player does not move" do
    world = build_world(
      starting_room: "cave",
      rooms: {
        "cave" => { "name" => "Cave", "description" => "Cave.", "creatures" => ["wolf"], "exits" => { "east" => "hall" } },
        "hall" => { "name" => "Hall", "description" => "Hall.", "exits" => { "west" => "cave" } }
      },
      creatures: {
        "wolf" => {
          "name" => "Wolf",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "cave", "duration" => 1 },
              { "room" => "hall", "duration" => 1 }
            ]
          }
        }
      }
    )
    combat_state = player_state_in("cave", combat: { "active" => true, "creature_id" => "wolf" })
    game = build_game(world_data: world, player_id: USER_ID, player_state: combat_state)

    3.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_includes game.room_state("cave")["creatures"], "wolf"
  end

  # ─── Turn counter test ────────────────────────────────────────────────────────

  test "turn counter increments on each process call" do
    world = build_world(
      starting_room: "room_a",
      rooms: { "room_a" => { "name" => "Room A", "description" => "A.", "exits" => {} } }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("room_a"))

    5.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_equal 5, game.turn_count
  end

  # ─── Creature patrol test ─────────────────────────────────────────────────────

  test "movement works for creatures same as NPCs" do
    world = build_world(
      starting_room: "hall",
      rooms: {
        "cave" => { "name" => "Cave", "description" => "Cave.", "creatures" => ["bat"], "exits" => { "east" => "hall" } },
        "hall" => { "name" => "Hall", "description" => "Hall.", "exits" => { "west" => "cave" } }
      },
      creatures: {
        "bat" => {
          "name" => "Bat",
          "movement" => {
            "type" => "patrol",
            "schedule" => [
              { "room" => "cave", "duration" => 2 },
              { "room" => "hall", "duration" => 2 }
            ]
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hall"))

    3.times { ClassicGame::NpcMovementProcessor.process(game: game, user_id: USER_ID) }

    assert_not_includes game.room_state("cave")["creatures"], "bat"
    assert_includes game.room_state("hall")["creatures"], "bat"
  end
end
