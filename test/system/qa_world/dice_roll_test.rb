# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class DiceRollTest < ApplicationSystemTestCase
    test "use lockpick triggers dice roll prompt" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("take lockpick", :return)
      assert_text "Lockpick"

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

      find(".terminal-input").send_keys("look", :return)
      assert_text "You need to ROLL first"
    end

    test "successful roll sets unlock flag and chest becomes openable" do
      visit dev_game_path
      find(".terminal-input").click

      roll_until_outcome("Success!")

      assert_text "The lock clicks open"

      find(".terminal-input").send_keys("open chest", :return)
      assert_text "Health Potion"
    end

    test "failed roll shows failure branch message and consumes lockpick" do
      visit dev_game_path
      find(".terminal-input").click

      roll_until_outcome("Failed.")

      assert_text "The lockpick snaps!"

      # Lockpick should be consumed (consume_on: failure)
      send_and_wait("use lockpick")
      assert_text "don't have"
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

      assert_text "TOTAL:"
    end

    test "chest contents can be taken after successful lockpick roll" do
      visit dev_game_path
      find(".terminal-input").click

      roll_until_outcome("Success!")

      find(".terminal-input").send_keys("open chest", :return)
      assert_text "Health Potion"

      find(".terminal-input").send_keys("take potion", :return)
      assert_text "You take the Health Potion"
    end

    test "using lockpick after success shows completed message instead of re-triggering roll" do
      visit dev_game_path
      find(".terminal-input").click

      roll_until_outcome("Success!")

      # Lockpick survives success (consume_on: failure) — try to use it again
      find(".terminal-input").send_keys("use lockpick", :return)
      assert_text "The chest lock is already open"
    end

    private

      # Navigate to tavern, take lockpick, use it, and roll.
      # Uses message-count sync to avoid stale text matching after restarts.
      def roll_until_outcome(desired, max_attempts: 20)
        max_attempts.times do |i|
          restart_game if i > 0

          send_and_wait("go east")
          send_and_wait("take lockpick")
          send_and_wait("use lockpick")
          send_and_wait("roll")

          break if page.has_text?(desired, wait: 3)
        end

        assert_text desired
      end

      # Send a command and wait for the engine response to appear by counting
      # new .game-message elements. This avoids matching stale text from prior
      # game rounds.
      def send_and_wait(text)
        count = all(".game-message", wait: false).count
        find(".terminal-input").send_keys(text, :return)
        assert_selector ".game-message", minimum: count + 2, wait: 5
      end

      def restart_game
        send_and_wait("restart")
        send_and_wait("yes")
      end
  end
end
