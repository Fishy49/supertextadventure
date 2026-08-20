# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class ItemsTest < ApplicationSystemTestCase
    test "take rusty_key from town_square" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      within("[id^='player_inventory_']") { assert_text "Rusty Key" }
    end

    test "drop item shows it in room" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("drop key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("look", :return)
      assert_text "Rusty Key"
    end

    test "use health_potion outside combat" do
      visit dev_game_path
      find(".terminal-input").click

      # Take the key
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Open the chest (need key in inventory)
      find(".terminal-input").send_keys("open chest", :return)
      assert_text "unlock the chest"

      # Take the potion
      find(".terminal-input").send_keys("take potion", :return)
      assert_text "Health Potion"

      # Use the potion
      find(".terminal-input").send_keys("use potion", :return)
      assert_text "revitalized"
    end
  end
end
