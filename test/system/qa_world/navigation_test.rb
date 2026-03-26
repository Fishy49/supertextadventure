# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class NavigationTest < ApplicationSystemTestCase
    test "move south from town_square to cave" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"
    end

    test "move east from town_square to tavern" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"
    end

    test "move west from town_square to market" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("go west", :return)
      assert_text "The Market"
    end

    test "locked exit blocks movement" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("go north", :return)
      assert_text "locked"
    end

    test "unlock exit via flag and move through" do
      visit dev_game_path

      # Talk to crier to set spoke_to_crier flag
      find(".terminal-input").click
      find(".terminal-input").send_keys("talk to crier", :return)
      assert_text "Hear ye"

      # Go east to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Talk to innkeeper about tower to set tower_unlocked flag
      find(".terminal-input").send_keys("talk to innkeeper about tower", :return)
      assert_text "tower can be unlocked"

      # Go back to town square
      find(".terminal-input").send_keys("go west", :return)
      assert_text "Town Square"

      # Now go north should work
      find(".terminal-input").send_keys("go north", :return)
      assert_text "Tower Top"
    end
  end
end
