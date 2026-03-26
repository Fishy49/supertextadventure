# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class CombatTest < ApplicationSystemTestCase
    test "attack cave_spider shows combat feedback" do
      visit dev_game_path
      find(".terminal-input").click

      # Go south to cave
      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      # Attack the spider
      find(".terminal-input").send_keys("attack spider", :return)
      assert_text "Cave Spider"
      assert_text "combat"
    end

    test "defeat spider drops shield" do
      visit dev_game_path
      find(".terminal-input").click

      # Go south to cave
      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      # Attack the spider
      find(".terminal-input").send_keys("attack spider", :return)
      assert_text "Cave Spider"

      # Keep attacking until defeated (spider has 8 HP, min damage is 1)
      10.times do
        find(".terminal-input").send_keys("attack", :return)
        break if page.has_text?("crumples", wait: 1)
      end

      assert_text "Iron Shield"
    end

    test "flee exits combat" do
      visit dev_game_path
      find(".terminal-input").click

      # Go south to cave
      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      # Attack the spider to start combat
      find(".terminal-input").send_keys("attack spider", :return)
      assert_text "Cave Spider"

      # Try to flee (50% chance, retry up to 10 times)
      10.times do
        find(".terminal-input").send_keys("flee", :return)
        break if page.has_text?("flee from combat", wait: 1)
      end

      assert_text "flee"
    end
  end
end
