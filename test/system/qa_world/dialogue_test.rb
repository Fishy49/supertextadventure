# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class DialogueTest < ApplicationSystemTestCase
    test "talk to crier shows greeting" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("talk to crier", :return)
      assert_text "Hear ye"
    end

    test "talk to innkeeper about base topic" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about rooms", :return)
      assert_text "five main areas"
    end

    test "flag-gated topic shows locked_text before flag" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern without talking to crier first
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about tower", :return)
      assert_text "don't share secrets"
    end

    test "flag-gated topic succeeds after flag set" do
      visit dev_game_path
      find(".terminal-input").click

      # Talk to crier to set spoke_to_crier flag
      find(".terminal-input").send_keys("talk to crier", :return)
      assert_text "Hear ye"

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about tower", :return)
      assert_text "tower can be unlocked"
    end

    test "leads_to topic chain" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about rooms", :return)
      assert_text "tower"
    end
  end
end
