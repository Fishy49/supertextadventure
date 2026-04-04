# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class CreatureInteractionTest < ApplicationSystemTestCase
    test "talk to cave spider shows talk_text" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      find(".terminal-input").send_keys("talk to spider", :return)
      assert_text "hisses"
    end

    test "talk to friendly rat shows talk_text" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to rat", :return)
      assert_text "squeaks"
    end

    test "hostile cave spider with moves condition attacks after threshold" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      # First two looks should not trigger combat
      find(".terminal-input").send_keys("look", :return)
      find(".terminal-input").send_keys("look", :return)

      # Third action should trigger the spider's aggression
      find(".terminal-input").send_keys("look", :return)
      assert_text "lunges at you"
    end
  end
end
