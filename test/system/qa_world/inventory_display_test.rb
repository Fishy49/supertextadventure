# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class InventoryDisplayTest < ApplicationSystemTestCase
    test "inventory header shows item count" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      within("[id^='player_inventory_']") do
        assert_text "1 item"
      end
    end

    test "inventory item expands to show ascii art and description" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      within("[id^='player_inventory_']") do
        # Detail should be hidden initially
        assert_no_css ".inventory-item-detail:not(.hidden)"

        # Click the toggle button
        find(".inventory-item-button").click

        # Detail should now be visible
        assert_css ".inventory-item-detail:not(.hidden)"

        # ASCII art should be present
        assert_css ".inventory-ascii"

        # Description should appear
        assert_text "rusty iron key"
      end
    end

    test "opening one item closes the previously open one" do
      visit dev_game_path
      find(".terminal-input").click

      # Pick up two items
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("open chest", :return)
      find(".terminal-input").send_keys("take potion", :return)
      assert_text "Health Potion"

      find(".terminal-input").send_keys("go west", :return)
      assert_text "Town Square"

      within("[id^='player_inventory_']") do
        buttons = all(".inventory-item-button")
        assert buttons.size >= 2, "Expected at least 2 inventory items"

        # Open first item
        buttons[0].click
        assert_css ".inventory-item-detail:not(.hidden)", count: 1

        # Open second item — first should close
        buttons[1].click
        assert_css ".inventory-item-detail:not(.hidden)", count: 1
      end
    end

    test "ascii art and details do not appear in the main chat output" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      # The inventory command redirects to sidebar
      find(".terminal-input").send_keys("inventory", :return)
      assert_text "Thine inventory is innith thine sidebar!"

      # ASCII art class should not appear in the message area
      within("[data-game-target='messages'], .message-container, #messages") do
        assert_no_css ".inventory-ascii"
      end
    end
  end
end
