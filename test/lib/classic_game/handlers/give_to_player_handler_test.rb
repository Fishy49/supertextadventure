# frozen_string_literal: true

require "test_helper"

class GiveToPlayerHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_1 = 1
  USER_2 = 2

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern",
          "description" => "A cozy inn.",
          "exits" => { "north" => "library" },
          "npcs" => ["innkeeper"]
        },
        "library" => {
          "name" => "The Library",
          "description" => "Books everywhere.",
          "exits" => { "south" => "tavern" }
        }
      },
      items: {
        "sword" => { "name" => "Sword", "keywords" => ["sword"] },
        "potion" => { "name" => "Potion", "keywords" => ["potion"] }
      },
      npcs: {
        "innkeeper" => {
          "name" => "Innkeeper",
          "keywords" => ["innkeeper"],
          "accepts_item" => "potion",
          "accept_message" => "Thanks for the potion!"
        }
      }
    )

    @game_users = [
      OpenStruct.new(user_id: USER_1, character_name: "Gandalf"),
      OpenStruct.new(user_id: USER_2, character_name: "Aragorn")
    ]
  end

  # ─── GIVE to co-located player ─────────────────────────────────────────────

  test "give item to co-located player succeeds" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: ["sword"]),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give sword to Aragorn")

    assert result[:success]
    assert_match(/Aragorn/i, result[:response])
    assert_match(/give/i, result[:response])
    assert_not_includes game.player_state(USER_1)["inventory"], "sword"
    assert_includes game.player_state(USER_2)["inventory"], "sword"
  end

  test "give item to player generates secondary message to receiver" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: ["sword"]),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give sword to Aragorn")

    secondary = result[:secondary_messages]
    assert secondary.present?
    receiver_msg = secondary.find { |m| m[:visible_to] == [USER_2.to_s] }
    assert receiver_msg, "Expected secondary message visible to player 2"
    assert_match(/gives you/i, receiver_msg[:text])
    assert_match(/Sword/i, receiver_msg[:text])
  end

  test "give item to player in different room fails" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: ["sword"]),
        USER_2 => player_state_in("library")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give sword to Aragorn")

    assert_not result[:success]
    assert_match(/not here/i, result[:response])
    assert_includes game.player_state(USER_1)["inventory"], "sword"
  end

  test "give item to player when item not in inventory fails" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: []),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give sword to Aragorn")

    assert_not result[:success]
  end

  # ─── GIVE falls through to NPC when no player matches ─────────────────────

  test "give to NPC name still delegates to NPC logic" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: ["potion"]),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give potion to innkeeper")

    assert result[:success]
    assert_match(/Thanks for the potion!/i, result[:response])
    assert_not_includes game.player_state(USER_1)["inventory"], "potion"
  end

  test "give with unknown target fails gracefully" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: ["sword"]),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give sword to wizard")

    assert_not result[:success]
  end

  # ─── Case insensitivity ────────────────────────────────────────────────────

  test "give matches player name case-insensitively" do
    game = build_multiplayer_game(
      world_data: @world,
      player_ids: [USER_1, USER_2],
      player_states: {
        USER_1 => player_state_in("tavern", inventory: ["sword"]),
        USER_2 => player_state_in("tavern")
      },
      game_users: @game_users
    )

    result = execute(game, USER_1, "give sword to aragorn")

    assert result[:success]
  end

  private

    def execute(game, user_id, input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::InteractHandler.new(game: game, user_id: user_id).handle(command)
    end
end
