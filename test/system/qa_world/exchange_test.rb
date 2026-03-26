# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class ExchangeTest < ApplicationSystemTestCase
    test "give gem to merchant receives enchanted_sword" do
      visit dev_game_path
      find(".terminal-input").click

      # Unlock tower: talk to crier, go east to tavern, talk about tower, go back
      find(".terminal-input").send_keys("talk to crier", :return)
      assert_text "Hear ye"

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about tower", :return)
      assert_text "tower can be unlocked"

      find(".terminal-input").send_keys("go west", :return)
      assert_text "Town Square"

      # Go north to tower top
      find(".terminal-input").send_keys("go north", :return)
      assert_text "Tower Top"

      # Take the gem
      find(".terminal-input").send_keys("take gem", :return)
      assert_text "Sparkling Gem"

      # Go back south to town square
      find(".terminal-input").send_keys("go south", :return)
      assert_text "Town Square"

      # Go west to market
      find(".terminal-input").send_keys("go west", :return)
      assert_text "The Market"

      # Give gem to merchant
      find(".terminal-input").send_keys("give gem to merchant", :return)
      assert_text "Enchanted Sword"
    end

    test "give wrong item to merchant is rejected" do
      visit dev_game_path
      find(".terminal-input").click

      # Take rusty key
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      # Go west to market
      find(".terminal-input").send_keys("go west", :return)
      assert_text "The Market"

      # Try to give key to merchant
      find(".terminal-input").send_keys("give key to merchant", :return)
      assert_text "doesn't want"
    end
  end
end
