# frozen_string_literal: true

require "test_helper"

class CreatureInteractionTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  # ─── TALK TO CREATURE ─────────────────────────────────────────────────────

  test "talk to non-hostile creature returns talk_text" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["rat"]
        }
      },
      creatures: {
        "rat" => {
          "name" => "Rat",
          "keywords" => ["rat"],
          "hostile" => false,
          "health" => 5,
          "attack" => 1,
          "talk_text" => "The rat looks at you with disdain."
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    command = ClassicGame::CommandParser.parse("talk to rat")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "The rat looks at you with disdain."
  end

  test "talk to creature with no talk_text returns default" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["rat"]
        }
      },
      creatures: {
        "rat" => {
          "name" => "Rat",
          "keywords" => ["rat"],
          "hostile" => false,
          "health" => 5,
          "attack" => 1
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    command = ClassicGame::CommandParser.parse("talk to rat")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "It has no clue what you're saying."
  end

  test "talk to creature not in room fails" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => []
        }
      },
      creatures: {
        "rat" => {
          "name" => "Rat",
          "keywords" => ["rat"],
          "hostile" => false,
          "health" => 5,
          "attack" => 1,
          "talk_text" => "Squeak."
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    command = ClassicGame::CommandParser.parse("talk to rat")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert_not result[:success]
    assert_includes result[:response].downcase, "don't see anyone"
  end

  test "talk to NPC takes priority over creature with same keyword" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "npcs" => ["bob"],
          "creatures" => ["bob_creature"]
        }
      },
      npcs: {
        "bob" => {
          "name" => "Bob",
          "keywords" => ["bob"],
          "dialogue" => { "greeting" => "Hello, friend!" }
        }
      },
      creatures: {
        "bob_creature" => {
          "name" => "Bob the Beast",
          "keywords" => ["bob"],
          "hostile" => false,
          "health" => 10,
          "attack" => 2,
          "talk_text" => "Growl."
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    command = ClassicGame::CommandParser.parse("talk to bob")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "Hello, friend!"
    assert_not_includes result[:response], "Growl."
  end

  # ─── AGGRESSIVE CREATURES (via Engine) ─────────────────────────────────────

  test "hostile creature with no attack_condition attacks after first action" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["wolf"]
        }
      },
      creatures: {
        "wolf" => {
          "name" => "Wolf",
          "keywords" => ["wolf"],
          "hostile" => true,
          "health" => 20,
          "attack" => 3
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    result = ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    assert_includes result[:response].downcase, "attacks you"
  end

  test "hostile creature with moves condition does not attack before threshold" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["spider"]
        }
      },
      creatures: {
        "spider" => {
          "name" => "Spider",
          "keywords" => ["spider"],
          "hostile" => true,
          "health" => 10,
          "attack" => 2,
          "attack_condition" => { "moves" => 3 }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")
    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    ps = game.player_state(USER_ID)
    assert_nil ps.dig("combat", "active"), "Combat should not be active before threshold"
  end

  test "hostile creature with moves condition attacks at threshold" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["spider"]
        }
      },
      creatures: {
        "spider" => {
          "name" => "Spider",
          "keywords" => ["spider"],
          "hostile" => true,
          "health" => 10,
          "attack" => 2,
          "attack_condition" => { "moves" => 3 }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")
    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")
    result = ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    assert_includes result[:response].downcase, "attacks you"
  end

  test "hostile creature with on_talk condition attacks when talked to" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["troll"]
        }
      },
      creatures: {
        "troll" => {
          "name" => "Troll",
          "keywords" => ["troll"],
          "hostile" => true,
          "health" => 15,
          "attack" => 4,
          "talk_text" => "The troll grunts.",
          "attack_condition" => { "on_talk" => true }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    result = ClassicGame::Engine.execute(game: game, user: user, command_text: "talk to troll")

    assert_includes result[:response], "The troll grunts."
    assert_includes result[:response].downcase, "attacks you"
  end

  test "hostile creature with on_talk condition does not attack on other actions" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["troll"]
        }
      },
      creatures: {
        "troll" => {
          "name" => "Troll",
          "keywords" => ["troll"],
          "hostile" => true,
          "health" => 15,
          "attack" => 4,
          "talk_text" => "The troll grunts.",
          "attack_condition" => { "on_talk" => true }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    ClassicGame::Engine.execute(game: game, user: user, command_text: "look")

    ps = game.player_state(USER_ID)
    assert_nil ps.dig("combat", "active"), "Combat should not be active on non-talk actions"
  end

  test "non-hostile creature never auto-attacks" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "creatures" => ["bunny"]
        }
      },
      creatures: {
        "bunny" => {
          "name" => "Bunny",
          "keywords" => ["bunny"],
          "hostile" => false,
          "health" => 5,
          "attack" => 1
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    5.times { ClassicGame::Engine.execute(game: game, user: user, command_text: "look") }

    ps = game.player_state(USER_ID)
    assert_nil ps.dig("combat", "active"), "Non-hostile creature should never initiate combat"
  end

  test "hostile creature with room_entries condition attacks after N entries" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room 1", "description" => "First room.",
          "exits" => { "east" => "room2" }
        },
        "room2" => {
          "name" => "Room 2", "description" => "Second room.",
          "exits" => { "west" => "room1" },
          "creatures" => ["ghost"]
        }
      },
      creatures: {
        "ghost" => {
          "name" => "Ghost",
          "keywords" => ["ghost"],
          "hostile" => true,
          "health" => 12,
          "attack" => 3,
          "attack_condition" => { "room_entries" => 2 }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    game.define_singleton_method(:starting_hp) { 10 }
    user = OpenStruct.new(id: USER_ID)

    # Entry 1: move to room2
    result1 = ClassicGame::Engine.execute(game: game, user: user, command_text: "go east")
    assert_not_includes result1[:response].downcase, "attacks you"

    # Move back to room1
    ClassicGame::Engine.execute(game: game, user: user, command_text: "go west")

    # Entry 2: move to room2 again — should trigger
    result2 = ClassicGame::Engine.execute(game: game, user: user, command_text: "go east")
    assert_includes result2[:response].downcase, "attacks you"
  end
end
