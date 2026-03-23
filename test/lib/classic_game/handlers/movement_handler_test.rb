# frozen_string_literal: true

require "test_helper"

class MovementHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  setup do
    @world = build_world(
      starting_room: "entrance",
      rooms: {
        "entrance" => {
          "name" => "Entrance Hall",
          "description" => "A grand entrance hall.",
          "exits" => { "north" => "library", "east" => "garden" }
        },
        "library" => {
          "name" => "The Library",
          "description" => "Books line every wall.",
          "exits" => { "south" => "entrance" }
        },
        "garden" => {
          "name" => "The Garden",
          "description" => "Sunlight filters through.",
          "exits" => { "west" => "entrance" }
        }
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID)
  end

  # ─── Basic movement ─────────────────────────────────────────────────────────

  test "moves player through a valid exit" do
    result = execute("go north")

    assert result[:success]
    assert_equal "library", @game.player_state(USER_ID)["current_room"]
  end

  test "response includes destination room name" do
    result = execute("go north")

    assert_includes result[:response], "The Library"
  end

  test "response includes room description" do
    result = execute("go north")

    assert_includes result[:response], "Books line every wall"
  end

  test "state_changes includes moved flag and room id" do
    result = execute("go north")

    assert result[:state_changes][:moved]
    assert_equal "library", result[:state_changes][:room]
  end

  test "records room in visited_rooms on first visit" do
    execute("go north")

    assert_includes @game.player_state(USER_ID)["visited_rooms"], "library"
  end

  test "does not duplicate visited_rooms on revisit" do
    execute("go north")
    execute("go south")
    execute("go north")

    count = @game.player_state(USER_ID)["visited_rooms"].count("library")
    assert_equal 1, count
  end

  test "fails when no direction given" do
    result = execute("go")

    assert_not result[:success]
  end

  test "fails for a direction with no exit" do
    result = execute("go west")

    assert_not result[:success]
    assert_includes result[:response].downcase, "can't go that way"
  end

  test "direction shorthand works (n, s, e, w)" do
    result = execute("n")

    assert result[:success]
    assert_equal "library", @game.player_state(USER_ID)["current_room"]
  end

  # ─── Complex exits: item requirement ────────────────────────────────────────

  test "complex exit blocked when player lacks required item" do
    world = locked_vault_world(require_item: "golden_key")
    game = build_game(world_data: world, player_id: USER_ID)

    result = move_north(game)

    assert_not result[:success]
    assert_includes result[:response], "vault is locked"
  end

  test "complex exit passes when player has required item" do
    world = locked_vault_world(require_item: "golden_key")
    game = build_game(
      world_data: world, player_id: USER_ID,
      player_state: player_state_in("entrance", inventory: ["golden_key"])
    )

    result = move_north(game)

    assert result[:success]
    assert_equal "vault", game.player_state(USER_ID)["current_room"]
  end

  # ─── Complex exits: flag requirement ────────────────────────────────────────

  test "complex exit blocked when required flag is not set" do
    world = flagged_door_world(flag: "lever_pulled")
    game = build_game(world_data: world, player_id: USER_ID)

    result = move_north(game)

    assert_not result[:success]
  end

  test "complex exit passes when required flag is set" do
    world = flagged_door_world(flag: "lever_pulled")
    game = build_game(world_data: world, player_id: USER_ID)
    game.set_flag("lever_pulled", true)

    result = move_north(game)

    assert result[:success]
    assert_equal "vault", game.player_state(USER_ID)["current_room"]
  end

  # ─── Hidden exits ───────────────────────────────────────────────────────────

  test "hidden exit cannot be used before being revealed" do
    world = hidden_exit_world
    game = build_game(world_data: world, player_id: USER_ID)

    result = move_north(game)

    assert_not result[:success]
    assert_includes result[:response].downcase, "can't go that way"
  end

  test "hidden exit can be used after being revealed" do
    world = hidden_exit_world
    game = build_game(world_data: world, player_id: USER_ID)
    game.reveal_exit("entrance", "north")

    result = move_north(game)

    assert result[:success]
    assert_equal "vault", game.player_state(USER_ID)["current_room"]
  end

  # ─── Room description content ───────────────────────────────────────────────

  test "room description lists visible items" do
    world = build_world(
      starting_room: "entrance",
      rooms: {
        "entrance" => { "name" => "Entrance", "description" => "A hall.", "exits" => { "north" => "library" } },
        "library" => {
          "name" => "Library", "description" => "Books.", "exits" => {},
          "items" => ["old_tome"]
        }
      },
      items: { "old_tome" => { "name" => "Old Tome", "keywords" => ["tome"] } }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    result = move_north(game)

    assert_includes result[:response], "Old Tome"
  end

  test "room description lists visible exits" do
    result = execute("go north")

    assert_includes result[:response], "SOUTH"
  end

  private

  def execute(input)
    command = ClassicGame::CommandParser.parse(input)
    ClassicGame::Handlers::MovementHandler.new(game: @game, user_id: USER_ID).handle(command)
  end

  def move_north(game)
    command = ClassicGame::CommandParser.parse("go north")
    ClassicGame::Handlers::MovementHandler.new(game: game, user_id: USER_ID).handle(command)
  end

  def locked_vault_world(require_item:)
    build_world(
      starting_room: "entrance",
      rooms: {
        "entrance" => {
          "name" => "Entrance", "description" => "A hall.",
          "exits" => { "north" => { "to" => "vault", "requires" => require_item, "locked_msg" => "The vault is locked." } }
        },
        "vault" => { "name" => "Vault", "description" => "Treasure!", "exits" => {} }
      },
      items: { require_item => { "name" => "Golden Key", "keywords" => ["key"] } }
    )
  end

  def flagged_door_world(flag:)
    build_world(
      starting_room: "entrance",
      rooms: {
        "entrance" => {
          "name" => "Entrance", "description" => "A hall.",
          "exits" => { "north" => { "to" => "vault", "requires_flag" => flag, "locked_msg" => "The door is sealed." } }
        },
        "vault" => { "name" => "Vault", "description" => "Treasure!", "exits" => {} }
      }
    )
  end

  def hidden_exit_world
    build_world(
      starting_room: "entrance",
      rooms: {
        "entrance" => {
          "name" => "Entrance", "description" => "A hall.",
          "exits" => { "north" => { "to" => "vault", "hidden" => true } }
        },
        "vault" => { "name" => "Vault", "description" => "Treasure!", "exits" => {} }
      }
    )
  end
end
