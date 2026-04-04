# frozen_string_literal: true

require "test_helper"

class MultiplayerNotifierTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  PLAYER_1 = 1
  PLAYER_2 = 2

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern",
          "description" => "A cozy inn.",
          "exits" => { "east" => "library" }
        },
        "library" => {
          "name" => "The Library",
          "description" => "Shelves of books.",
          "exits" => { "west" => "tavern" }
        }
      }
    )
  end

  # ─── observer_messages ──────────────────────────────────────────────────────

  test "observer_messages returns message for co-located player" do
    game = two_player_game(p1_room: "tavern", p2_room: "tavern")
    result = { success: true, response: "You look around the tavern." }

    msgs = ClassicGame::MultiplayerNotifier.observer_messages(game, PLAYER_1, "look", result)

    assert_equal 1, msgs.length
    assert_includes msgs.first[:user_ids], PLAYER_2.to_s
    assert_includes msgs.first[:content], "Alice"
    assert_includes msgs.first[:content], "look"
    assert_includes msgs.first[:content], "You look around the tavern."
  end

  test "observer_messages returns empty array when players are in different rooms" do
    game = two_player_game(p1_room: "tavern", p2_room: "library")
    result = { success: true, response: "You look around." }

    msgs = ClassicGame::MultiplayerNotifier.observer_messages(game, PLAYER_1, "look", result)

    assert_empty msgs
  end

  test "observer_messages excludes the acting player" do
    game = two_player_game(p1_room: "tavern", p2_room: "tavern")
    result = { success: true, response: "You look around." }

    msgs = ClassicGame::MultiplayerNotifier.observer_messages(game, PLAYER_1, "look", result)

    assert_not_includes msgs.flat_map { |m| m[:user_ids] }, PLAYER_1.to_s
  end

  # ─── arrival_message ────────────────────────────────────────────────────────

  test "arrival_message returns message for players already in destination room" do
    game = two_player_game(p1_room: "tavern", p2_room: "library")

    msg = ClassicGame::MultiplayerNotifier.arrival_message(game, PLAYER_2, "tavern")

    assert_not_nil msg
    assert_includes msg[:user_ids], PLAYER_1.to_s
    assert_includes msg[:content], "Bob"
    assert_includes msg[:content], "arrived"
  end

  test "arrival_message returns nil when destination room is empty" do
    game = two_player_game(p1_room: "tavern", p2_room: "library")

    msg = ClassicGame::MultiplayerNotifier.arrival_message(game, PLAYER_1, "library")

    assert_nil msg
  end

  # ─── global_event_messages ──────────────────────────────────────────────────

  test "global_event_messages notifies player in room affected by flag change" do
    world = build_world(
      starting_room: "lever_room",
      rooms: {
        "lever_room" => {
          "name" => "Lever Room",
          "description" => "A lever is here.",
          "exits" => {}
        },
        "door_room" => {
          "name" => "Door Room",
          "description" => "A heavy stone door.",
          "exits" => {
            "north" => {
              "to" => "beyond",
              "requires_flag" => "door_open",
              "remote_event_msg" => "The stone door grinds open!"
            }
          }
        },
        "beyond" => { "name" => "Beyond", "description" => "Freedom.", "exits" => {} }
      }
    )
    game = build_multiplayer_game(
      world_data: world,
      players: {
        PLAYER_1 => player_state_in("lever_room"),
        PLAYER_2 => player_state_in("door_room")
      }
    )
    game.game_state["player_names"] = { PLAYER_1.to_s => "Alice", PLAYER_2.to_s => "Bob" }

    msgs = ClassicGame::MultiplayerNotifier.global_event_messages(
      game, { "door_open" => true }, PLAYER_1
    )

    assert_equal 1, msgs.length
    assert_includes msgs.first[:user_ids], PLAYER_2.to_s
    assert_equal "The stone door grinds open!", msgs.first[:content]
  end

  test "global_event_messages uses fallback message when remote_event_msg absent" do
    world = build_world(
      starting_room: "lever_room",
      rooms: {
        "lever_room" => { "name" => "Lever Room", "description" => ".", "exits" => {} },
        "door_room" => {
          "name" => "Door Room", "description" => ".",
          "exits" => {
            "north" => { "to" => "beyond", "requires_flag" => "door_open" }
          }
        },
        "beyond" => { "name" => "Beyond", "description" => ".", "exits" => {} }
      }
    )
    game = build_multiplayer_game(
      world_data: world,
      players: {
        PLAYER_1 => player_state_in("lever_room"),
        PLAYER_2 => player_state_in("door_room")
      }
    )

    msgs = ClassicGame::MultiplayerNotifier.global_event_messages(
      game, { "door_open" => true }, PLAYER_1
    )

    assert_equal 1, msgs.length
    assert_includes msgs.first[:content], "distance"
  end

  test "global_event_messages returns empty when no flag changes" do
    game = two_player_game(p1_room: "tavern", p2_room: "library")

    msgs = ClassicGame::MultiplayerNotifier.global_event_messages(game, {}, PLAYER_1)

    assert_empty msgs
  end

  # ─── room description lists other players ───────────────────────────────────

  test "room description includes other players present when using look" do
    game = two_player_game(p1_room: "tavern", p2_room: "tavern")
    command = ClassicGame::CommandParser.parse("look")

    result = ClassicGame::Handlers::ExamineHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_includes result[:response], "Bob"
    assert_includes result[:response], "Also here"
  end

  test "room description does not list other players in different rooms" do
    game = two_player_game(p1_room: "tavern", p2_room: "library")
    command = ClassicGame::CommandParser.parse("look")

    result = ClassicGame::Handlers::ExamineHandler.new(game: game, user_id: PLAYER_1).handle(command)

    assert_not_includes result[:response], "Bob"
  end

  # ─── waiting_indicator ──────────────────────────────────────────────────────

  test "waiting_indicator shows your turn message for current player" do
    game = two_player_game(p1_room: "tavern", p2_room: "tavern")
    game.initialize_turn_order([PLAYER_1.to_s, PLAYER_2.to_s])
    game.game_state["turn_state"]["current_user_id"] = PLAYER_1.to_s

    msg = ClassicGame::MultiplayerNotifier.waiting_indicator(game, PLAYER_1)

    assert_includes msg, "your turn"
  end

  test "waiting_indicator shows waiting message for off-turn player" do
    game = two_player_game(p1_room: "tavern", p2_room: "tavern")
    game.initialize_turn_order([PLAYER_1.to_s, PLAYER_2.to_s])
    game.game_state["turn_state"]["current_user_id"] = PLAYER_1.to_s
    game.game_state["player_names"] = { PLAYER_1.to_s => "Alice", PLAYER_2.to_s => "Bob" }

    msg = ClassicGame::MultiplayerNotifier.waiting_indicator(game, PLAYER_2)

    assert_includes msg, "Alice"
  end

  private

    def two_player_game(p1_room:, p2_room:)
      game = build_multiplayer_game(
        world_data: @world,
        players: {
          PLAYER_1 => player_state_in(p1_room),
          PLAYER_2 => player_state_in(p2_room)
        }
      )
      game.game_state["player_names"] = {
        PLAYER_1.to_s => "Alice",
        PLAYER_2.to_s => "Bob"
      }
      game
    end
end
