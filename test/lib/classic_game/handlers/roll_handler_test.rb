# frozen_string_literal: true

require "test_helper"

class RollHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  setup do
    @world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Test Room",
          "description" => "A plain room.",
          "exits" => {
            "north" => {
              "to" => "room2",
              "requires_flag" => "door_unlocked",
              "locked_msg" => "The door is locked."
            }
          },
          "items" => ["lockpick"]
        },
        "room2" => {
          "name" => "Room 2",
          "description" => "Another room.",
          "exits" => {}
        }
      },
      items: {
        "lockpick" => {
          "name" => "Lockpick",
          "keywords" => %w[lockpick pick],
          "takeable" => true,
          "dice_roll" => {
            "dc" => 12,
            "stat" => "dexterity",
            "dice" => "1d20",
            "on_success" => {
              "sets_flag" => "door_unlocked",
              "message" => "The lock clicks open."
            },
            "on_failure" => {
              "sets_flag" => "lock_jammed",
              "message" => "You scratch up the lock badly."
            }
          }
        }
      },
      npcs: {
        "guard_captain" => {
          "name" => "Guard Captain",
          "keywords" => %w[guard captain],
          "dialogue" => {
            "greeting" => "Move along.",
            "default" => "I have nothing to say.",
            "topics" => {
              "door" => {
                "keywords" => %w[door entrance],
                "text" => "There is a secret passage around back.",
                "locked_text" => "I don't know what you mean."
              }
            }
          }
        }
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID,
                       player_state: player_state_in("room1", inventory: ["lockpick"]))
  end

  # ─── SUCCESSFUL ROLL ──────────────────────────────────────────────────────
  # DC 1 with 1d20 guarantees success (min roll is 1 which equals DC)

  test "successful roll sets flag and returns success message" do
    roll_data = guaranteed_success_roll.merge(
      "on_success" => { "sets_flag" => "door_unlocked", "message" => "The lock clicks open." },
      "on_failure" => { "sets_flag" => "lock_jammed", "message" => "You scratch up the lock badly." }
    )
    apply_pending_roll(roll_data)

    result = execute_roll("roll")

    assert result[:success]
    assert_includes result[:response], "Success!"
    assert_includes result[:response], "The lock clicks open."
    assert @game.get_flag("door_unlocked")
    assert_nil @game.player_state(USER_ID)["pending_roll"]
  end

  # ─── FAILED ROLL ──────────────────────────────────────────────────────────
  # DC 100 with 1d20 guarantees failure (max roll is 20 which is < 100)

  test "failed roll executes on_failure directive and returns failure message" do
    roll_data = guaranteed_failure_roll.merge(
      "on_success" => { "sets_flag" => "door_unlocked", "message" => "The lock clicks open." },
      "on_failure" => { "sets_flag" => "lock_jammed", "message" => "You scratch up the lock badly." }
    )
    apply_pending_roll(roll_data)

    result = execute_roll("roll")

    assert result[:success]
    assert_includes result[:response], "Failed."
    assert_includes result[:response], "You scratch up the lock badly."
    assert @game.get_flag("lock_jammed")
    assert_nil @game.player_state(USER_ID)["pending_roll"]
  end

  # ─── UNLOCKS_DIALOGUE DIRECTIVE ───────────────────────────────────────────

  test "roll with unlocks_dialogue directive sets dialogue flag" do
    roll_data = guaranteed_failure_roll.merge(
      "on_success" => { "sets_flag" => "ok", "message" => "Ok." },
      "on_failure" => {
        "unlocks_dialogue" => { "npc" => "guard_captain", "topic" => "door" },
        "message" => "You fail. Maybe the guard captain knows another way."
      }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert @game.get_flag("dialogue_unlocked_door")
  end

  # ─── UNLOCKS_EXIT DIRECTIVE ───────────────────────────────────────────────

  test "roll with unlocks_exit directive unlocks the exit" do
    roll_data = guaranteed_success_roll.merge(
      "on_success" => {
        "unlocks_exit" => { "direction" => "north" },
        "message" => "The door swings open."
      },
      "on_failure" => { "message" => "Nope." }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert @game.exit_unlocked?("room1", "north")
  end

  # ─── NON-ROLL COMMAND WHILE PENDING ───────────────────────────────────────

  test "non-roll command while roll is pending returns prompt to roll" do
    roll_data = guaranteed_success_roll.merge(
      "on_success" => { "message" => "Ok." },
      "on_failure" => { "message" => "Nope." }
    )
    apply_pending_roll(roll_data)

    result = execute_roll("go north")

    assert_not result[:success]
    assert_includes result[:response], "You need to ROLL first"
  end

  # ─── ROLL WITH NO PENDING ROLL ───────────────────────────────────────────

  test "roll with no pending roll returns nothing to roll for" do
    result = execute_roll("roll")

    assert_not result[:success]
    assert_includes result[:response], "Nothing to roll for."
  end

  # ─── USE ITEM WITH DICE_ROLL SETS PENDING_ROLL ───────────────────────────

  test "using item with dice_roll sets pending_roll and returns attempt message" do
    command = ClassicGame::CommandParser.parse("use lockpick")
    result = ClassicGame::Handlers::ItemHandler.new(game: @game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "Type ROLL"
    assert @game.player_state(USER_ID)["pending_roll"]
    assert_equal "lockpick", @game.player_state(USER_ID).dig("pending_roll", "source_item")
  end

  # ─── INVALID DICE_ROLL DATA ──────────────────────────────────────────────

  test "item with dice_roll missing on_failure is rejected" do
    bad_world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Test Room",
          "description" => "A room.",
          "exits" => {},
          "items" => ["bad_pick"]
        }
      },
      items: {
        "bad_pick" => {
          "name" => "Bad Pick",
          "keywords" => ["pick"],
          "takeable" => true,
          "dice_roll" => {
            "dc" => 10,
            "on_success" => { "sets_flag" => "ok", "message" => "It works." }
          }
        }
      }
    )
    bad_game = build_game(world_data: bad_world, player_id: USER_ID,
                          player_state: player_state_in("room1", inventory: ["bad_pick"]))

    command = ClassicGame::CommandParser.parse("use pick")
    result = ClassicGame::Handlers::ItemHandler.new(game: bad_game, user_id: USER_ID).handle(command)

    assert_not result[:success]
    assert_includes result[:response], "Invalid world data"
  end

  # ─── CONSUME_ON DIRECTIVE ─────────────────────────────────────────────────

  test "consume_on failure removes item from inventory on failed roll" do
    roll_data = guaranteed_failure_roll.merge(
      "consume_on" => "failure",
      "on_success" => { "message" => "It works." },
      "on_failure" => { "message" => "The pick snaps!" }
    )
    apply_pending_roll(roll_data)

    result = execute_roll("roll")

    assert result[:success]
    assert_includes result[:response], "The pick snaps!"
    assert_not_includes @game.player_state(USER_ID)["inventory"], "lockpick"
  end

  test "consume_on failure keeps item on successful roll" do
    roll_data = guaranteed_success_roll.merge(
      "consume_on" => "failure",
      "on_success" => { "message" => "It works." },
      "on_failure" => { "message" => "It breaks." }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert_includes @game.player_state(USER_ID)["inventory"], "lockpick"
  end

  test "consume_on success removes item from inventory on successful roll" do
    roll_data = guaranteed_success_roll.merge(
      "consume_on" => "success",
      "on_success" => { "message" => "Used up!" },
      "on_failure" => { "message" => "Nope." }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert_not_includes @game.player_state(USER_ID)["inventory"], "lockpick"
  end

  test "consume_on success keeps item on failed roll" do
    roll_data = guaranteed_failure_roll.merge(
      "consume_on" => "success",
      "on_success" => { "message" => "Used up!" },
      "on_failure" => { "message" => "Nope." }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert_includes @game.player_state(USER_ID)["inventory"], "lockpick"
  end

  test "consume_on any removes item regardless of outcome" do
    roll_data = guaranteed_success_roll.merge(
      "consume_on" => "any",
      "on_success" => { "message" => "Done." },
      "on_failure" => { "message" => "Nope." }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert_not_includes @game.player_state(USER_ID)["inventory"], "lockpick"
  end

  test "no consume_on keeps item in inventory" do
    roll_data = guaranteed_success_roll.merge(
      "on_success" => { "message" => "Done." },
      "on_failure" => { "message" => "Nope." }
    )
    apply_pending_roll(roll_data)

    execute_roll("roll")

    assert_includes @game.player_state(USER_ID)["inventory"], "lockpick"
  end

  # ─── PLAYER RECEIVES CORRECT BRANCH MESSAGE ──────────────────────────────

  test "player always receives the message from the success branch on success" do
    roll_data = guaranteed_success_roll.merge(
      "on_success" => { "message" => "The lock clicks open." },
      "on_failure" => { "message" => "You scratch up the lock badly." }
    )
    apply_pending_roll(roll_data)

    result = execute_roll("roll")
    assert_includes result[:response], "The lock clicks open."
    assert_not_includes result[:response], "You scratch up the lock badly."
  end

  test "player always receives the message from the failure branch on failure" do
    roll_data = guaranteed_failure_roll.merge(
      "on_success" => { "message" => "The lock clicks open." },
      "on_failure" => { "message" => "You scratch up the lock badly." }
    )
    apply_pending_roll(roll_data)

    result = execute_roll("roll")
    assert_includes result[:response], "You scratch up the lock badly."
    assert_not_includes result[:response], "The lock clicks open."
  end

  private

    def execute_roll(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::RollHandler.new(game: @game, user_id: USER_ID).handle(command)
    end

    def apply_pending_roll(roll_data)
      new_state = @game.player_state(USER_ID).dup
      new_state["pending_roll"] = roll_data
      @game.update_player_state(USER_ID, new_state)
    end

    # DC 1 with 1d20 → always succeeds (min roll = 1 = DC)
    def guaranteed_success_roll
      { "dc" => 1, "dice" => "1d20", "source_item" => "lockpick" }
    end

    # DC 100 with 1d20 → always fails (max roll = 20 < 100)
    def guaranteed_failure_roll
      { "dc" => 100, "dice" => "1d20", "source_item" => "lockpick" }
    end
end
