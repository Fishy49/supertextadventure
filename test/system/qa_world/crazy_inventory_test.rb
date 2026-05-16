# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class CrazyInventoryTest < ApplicationSystemTestCase
    test "inventory items render ASCII art only after click" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("take key", :return)
      within("[id^='player_inventory_']") { assert_text "Rusty Key" }

      within("[id^='player_inventory_']") do
        assert_no_text "▓"
        click_on "Rusty Key"
        assert_text "▓"
      end
    end

    test "clicking second inventory item reveals its own art" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("open chest", :return)
      assert_text "unlock the chest"

      find(".terminal-input").send_keys("take potion", :return)
      assert_text "Health Potion"

      within("[id^='player_inventory_']") do
        click_on "Health Potion"
        assert_text "°"
        assert_no_text "▓"
      end
    end

    test "ASCII art renders inside sidebar, not chat output" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("take key", :return)
      within("[id^='player_inventory_']") { assert_text "Rusty Key" }

      within("[id^='player_inventory_']") do
        click_on "Rusty Key"
        assert_text "▓"
      end

      within("#message-content-wrapper") do
        assert_no_text "▓"
      end
    end

    test "empty inventory shows decorative empty-state art" do
      visit dev_game_path

      within("[id^='player_inventory_']") do
        assert_text "thine sack lieth empty"
        assert_selector "pre"
      end
    end
  end
end
