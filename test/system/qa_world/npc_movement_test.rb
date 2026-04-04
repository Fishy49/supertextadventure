# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class NpcMovementTest < ApplicationSystemTestCase
    test "innkeeper patrol: arrives in town_square after enough ticks" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern — tick 1
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"
      assert_text "Innkeeper"

      # Look around — tick 2
      find(".terminal-input").send_keys("look", :return)
      assert_text "The Tavern"

      # Go back to town square — tick 3, innkeeper moves to town_square
      find(".terminal-input").send_keys("go west", :return)
      assert_text "Town Square"
      assert_text "The innkeeper strolls in."
    end

    test "innkeeper patrol: stays put while player is in tavern" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Do several actions in tavern — innkeeper should stay because of unless_player_in
      find(".terminal-input").send_keys("look", :return)
      find(".terminal-input").send_keys("look", :return)
      find(".terminal-input").send_keys("look", :return)
      find(".terminal-input").send_keys("look", :return)

      # Innkeeper should still be present
      find(".terminal-input").send_keys("examine innkeeper", :return)
      assert_text "jovial woman"
    end
  end
end
