# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class ContainersTest < ApplicationSystemTestCase
    test "open chest without key is rejected" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Try to open chest without the key
      find(".terminal-input").send_keys("open chest", :return)
      assert_text "locked"
    end

    test "open chest with key shows contents" do
      visit dev_game_path
      find(".terminal-input").click

      # Take the key first
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Open the chest
      find(".terminal-input").send_keys("open chest", :return)
      assert_text "Health Potion"
    end
  end
end
