# frozen_string_literal: true

require "test_helper"

class MovementProcessorTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1
  FakeUser = Struct.new(:id)

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

    process(game)
    assert_includes game.room_state("tavern")["npcs"], "barkeep"

    process(game)
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
  end

  test "patrol creature follows same DSL as NPC" do
    world = build_world(
      starting_room: "hallway",
      rooms: {
        "hallway" => { "name" => "Hallway", "description" => "A hallway.", "exits" => {} },
        "cave" => {
          "name" => "Cave", "description" => "A dark cave.",
          "exits" => { "east" => "tunnel" }, "creatures" => ["bat"]
        },
        "tunnel" => {
          "name" => "Tunnel", "description" => "A narrow tunnel.",
          "exits" => { "west" => "cave" }
        }
      },
      creatures: {
        "bat" => {
          "name" => "Bat", "keywords" => ["bat"],
          "description" => "A screeching bat.", "health" => 2, "attack" => 1,
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
    user = FakeUser.new(USER_ID)

    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
  end

  # ─── AC: Repetitive route movement ─────────────────────────────────────────

  test "patrol NPC cycles back to first stop after completing route" do
    world = build_patrol_world(stay_durations: [1, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    process(game)
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"

    process(game)
    assert_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_not_includes game.room_state("storage_room")["npcs"], "barkeep"

    process(game)
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
  end

  test "patrol NPC stays in room for correct number of ticks" do
    world = build_patrol_world(stay_durations: [3, 1])
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("hallway"))

    process(game)
    process(game)
    assert_includes game.room_state("tavern")["npcs"], "barkeep"

    process(game)
    assert_not_includes game.room_state("tavern")["npcs"], "barkeep"
    assert_includes game.room_state("storage_room")["npcs"], "barkeep"
  end
end
