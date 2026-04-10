# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class NpcMovementTest < ApplicationSystemTestCase
    test "patrol guard starts in town square" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("look", :return)
      assert_text "Town Guard"
    end

    test "patrol guard moves to tavern after enough turns" do
      visit dev_game_path
      find(".terminal-input").click

      # Issue enough commands to push the guard past its 3-turn duration in town_square
      4.times { find(".terminal-input").send_keys("look", :return) }

      # Guard should have moved; check the tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"
      find(".terminal-input").send_keys("look", :return)
      assert_text "Town Guard"
    end
  end
end
