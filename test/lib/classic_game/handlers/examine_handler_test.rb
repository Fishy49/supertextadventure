# frozen_string_literal: true

require "test_helper"

class ExamineHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  setup do
    @world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Test Room",
          "description" => "A plain room.",
          "exits" => {}
        }
      },
      items: {
        "sword" => { "name" => "Iron Sword", "keywords" => ["sword"], "takeable" => true }
      }
    )
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("room1", inventory: ["sword"])
    )
  end

  test "inventory command returns sidebar redirect message and does not list items" do
    command = ClassicGame::CommandParser.parse("inventory")
    result = ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_equal "Your inventory is shown in the sidebar.", result[:response]
    assert_not_includes result[:response], "Iron Sword"
    assert_not_includes result[:response], "sword"
  end

  test "inv alias returns sidebar redirect message" do
    command = ClassicGame::CommandParser.parse("inv")
    result = ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_equal "Your inventory is shown in the sidebar.", result[:response]
  end

  test "i alias returns sidebar redirect message" do
    command = ClassicGame::CommandParser.parse("i")
    result = ClassicGame::Handlers::ExamineHandler.new(game: @game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_equal "Your inventory is shown in the sidebar.", result[:response]
  end

  test "inventory command with empty inventory returns sidebar redirect message" do
    game = build_game(world_data: @world, player_id: USER_ID)
    command = ClassicGame::CommandParser.parse("inventory")
    result = ClassicGame::Handlers::ExamineHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_equal "Your inventory is shown in the sidebar.", result[:response]
  end
end
