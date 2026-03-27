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
      assert_text(/Success!|Failed\./)
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

    test "successful roll sets unlock flag and chest becomes openable" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      # Retry until we roll a success (DC 12 on 1d20, ~55% chance each attempt)
      20.times do
        find(".terminal-input").send_keys("use lockpick", :return)
        assert_text "Type ROLL"
        find(".terminal-input").send_keys("roll", :return)
        break if page.has_text?("Success!", wait: 2)
      end

      assert_text "Success!"
      assert_text "The lock clicks open"

      # The unlock flag should now allow opening the chest without the key
      find(".terminal-input").send_keys("open chest", :return)
      assert_text "Health Potion"
    end

    test "failed roll shows failure branch message" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      # Retry until we roll a failure (DC 12 on 1d20, ~45% chance each attempt)
      20.times do
        find(".terminal-input").send_keys("use lockpick", :return)
        assert_text "Type ROLL"
        find(".terminal-input").send_keys("roll", :return)
        break if page.has_text?("Failed.", wait: 2)
      end

      assert_text "Failed."
      assert_text "The pick slips and bends"
    end

    test "rolling dice creates a dice event message showing the roll total" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      find(".terminal-input").send_keys("use lockpick", :return)
      assert_text "Type ROLL"

      find(".terminal-input").send_keys("roll", :return)
      assert_text(/Success!|Failed\./)

      # A dice event message with the roll breakdown should appear
      assert_text "TOTAL:"
    end

    test "chest contents can be taken after successful lockpick roll" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

      20.times do
        find(".terminal-input").send_keys("use lockpick", :return)
        assert_text "Type ROLL"
        find(".terminal-input").send_keys("roll", :return)
        break if page.has_text?("Success!", wait: 2)
      end

      assert_text "Success!"

      find(".terminal-input").send_keys("open chest", :return)
      assert_text "Health Potion"

      find(".terminal-input").send_keys("take potion", :return)
      assert_text "You take the Health Potion"
    end
  end
end
