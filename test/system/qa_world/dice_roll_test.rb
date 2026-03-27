# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class DiceRollTest < ApplicationSystemTestCase
    test "use lockpick triggers dice roll prompt" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern, get the lockpick from the innkeeper's storeroom
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Pick up the lockpick (placed in tavern by QA world)
      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      # Use the lockpick to trigger a dice roll
      find(".terminal-input").send_keys("use lockpick", :return)
      assert_text "Type ROLL"
    end

    test "rolling dice after using lockpick resolves the roll" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      find(".terminal-input").send_keys("use lockpick", :return)
      assert_text "Type ROLL"

      # Roll the dice — outcome is random, but we should see either Success or Failed
      find(".terminal-input").send_keys("roll", :return)
      assert_selector ".message", text: /Success!|Failed\./
    end

    test "non-roll command while roll pending is rejected" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      find(".terminal-input").send_keys("use lockpick", :return)
      assert_text "Type ROLL"

      # Try a non-roll command
      find(".terminal-input").send_keys("look", :return)
      assert_text "You need to ROLL first"
    end
  end
end
