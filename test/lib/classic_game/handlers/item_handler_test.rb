# frozen_string_literal: true

require "test_helper"

class ItemHandlerTest < ActiveSupport::TestCase
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
          "items" => %w[sword chest]
        }
      },
      items: {
        "sword" => { "name" => "Iron Sword", "keywords" => %w[sword iron], "takeable" => true },
        "shield" => { "name" => "Wooden Shield", "keywords" => ["shield"], "takeable" => true },
        "boulder" => { "name" => "Heavy Boulder", "keywords" => ["boulder"], "takeable" => false,
                       "cant_take_msg" => "It's too heavy to lift." },
        "chest" => {
          "name" => "Wooden Chest", "keywords" => ["chest"], "is_container" => true,
          "starts_closed" => false, "contents" => ["gold_coin"]
        },
        "gold_coin" => { "name" => "Gold Coin", "keywords" => %w[coin gold], "takeable" => true },
        "key" => {
          "name" => "Brass Key", "keywords" => %w[key brass], "takeable" => true,
          "on_use" => { "type" => "unlock", "sets_flag" => "gate_unlocked", "success_msg" => "The gate clicks open." }
        },
        "torch" => {
          "name" => "Torch", "keywords" => ["torch"], "takeable" => true,
          "on_use" => { "type" => "message", "text" => "The torch flickers." }
        }
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID)
  end

  # ─── TAKE ───────────────────────────────────────────────────────────────────

  test "take item in room adds it to inventory" do
    result = execute("take sword")

    assert result[:success]
    assert_includes @game.player_state(USER_ID)["inventory"], "sword"
  end

  test "take item removes it from the room" do
    execute("take sword")

    assert_not_includes @game.room_state("room1")["items"], "sword"
  end

  test "take confirms with item name in response" do
    result = execute("take sword")

    assert_includes result[:response], "Iron Sword"
  end

  test "take fails when item is not in room" do
    result = execute("take shield")

    assert_not result[:success]
    assert_includes result[:response].downcase, "don't see"
  end

  test "take fails for non-takeable item" do
    @game.room_state("room1")["items"] << "boulder"
    result = execute("take boulder")

    assert_not result[:success]
    assert_includes result[:response], "too heavy"
  end

  test "take fails with no target" do
    result = execute("take")

    assert_not result[:success]
  end

  test "take item from open container in room" do
    # chest starts open with gold_coin inside
    result = execute("take coin")

    assert result[:success]
    assert_includes @game.player_state(USER_ID)["inventory"], "gold_coin"
  end

  test "cannot take item from closed container" do
    @game.close_container("chest")
    result = execute("take coin")

    assert_not result[:success]
  end

  # ─── DROP ───────────────────────────────────────────────────────────────────

  test "drop item from inventory adds it to room" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["shield"])
    result = execute("drop shield")

    assert result[:success]
    assert_includes @game.room_state("room1")["items"], "shield"
    assert_not_includes @game.player_state(USER_ID)["inventory"], "shield"
  end

  test "drop confirms with item name in response" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["shield"])
    result = execute("drop shield")

    assert_includes result[:response], "Wooden Shield"
  end

  test "drop fails when item not in inventory" do
    result = execute("drop sword")

    assert_not result[:success]
    assert_includes result[:response].downcase, "don't have"
  end

  test "drop fails with no target" do
    result = execute("drop")

    assert_not result[:success]
  end

  # ─── USE ────────────────────────────────────────────────────────────────────

  test "use item with message type returns the message" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["torch"])
    result = execute("use torch")

    assert result[:success]
    assert_includes result[:response], "flickers"
  end

  test "use item with unlock type sets the flag" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["key"])
    result = execute("use key")

    assert result[:success]
    assert @game.get_flag("gate_unlocked")
    assert_includes result[:response], "clicks open"
  end

  test "use fails when item not in inventory" do
    result = execute("use sword")

    assert_not result[:success]
    assert_includes result[:response].downcase, "don't have"
  end

  test "use fails with no target" do
    result = execute("use")

    assert_not result[:success]
  end

  test "use item with no on_use action fails gracefully" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("room1", inventory: ["sword"])
    result = execute("use sword")

    assert_not result[:success]
    assert_includes result[:response].downcase, "can't use"
  end

  # ─── USE ON EXIT ────────────────────────────────────────────────────────────

  test "use item on locked exit unlocks it" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "items" => [],
          "exits" => {
            "north" => {
              "to" => "room2",
              "use_item" => "magic_key",
              "permanently_unlock" => true,
              "on_unlock" => "The door swings open!",
              "locked_msg" => "The door is locked."
            }
          }
        },
        "room2" => { "name" => "Room 2", "description" => "Another room.", "exits" => {} }
      },
      items: { "magic_key" => { "name" => "Magic Key", "keywords" => %w[key magic] } }
    )
    game = build_game(world_data: world, player_id: USER_ID,
                      player_state: player_state_in("room1", inventory: ["magic_key"]))

    command = ClassicGame::CommandParser.parse("use key on north")
    result = ClassicGame::Handlers::ItemHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert game.exit_unlocked?("room1", "north")
    assert_includes result[:response], "swings open"
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::ItemHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
