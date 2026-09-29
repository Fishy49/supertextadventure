# frozen_string_literal: true

require "test_helper"

module ClassicGame
  class EngineTest < ActiveSupport::TestCase
    include ClassicGameTestHelper

    test "a defeated player is not attacked again while waiting to restart" do
      world = build_world(
        rooms: { "lair" => { "name" => "Lair", "description" => "Dark.", "exits" => {}, "creatures" => ["ogre"] } },
        creatures: { "ogre" => { "name" => "Ogre", "description" => "Big.", "health" => 50, "attack" => 100, "hostile" => true } }
      )
      game = build_game(world_data: world)
      user = FakeUser.new(1)

      # The ogre either strikes first and kills outright, or the player gets
      # the first swing and dies on the retaliation. Either way: dead.
      first = execute_engine(game, user, "look")
      first = execute_engine(game, user, "attack") unless game.player_state(1)["pending_restart"]
      assert_includes first[:response], "GAME OVER"
      assert game.player_state(1)["pending_restart"]

      second = execute_engine(game, user, "look")
      assert_not_includes second[:response], "attacks you"
      assert_not_includes second[:response], "GAME OVER"
      assert_includes second[:response], "=== Lair ==="
    end
  end
end
