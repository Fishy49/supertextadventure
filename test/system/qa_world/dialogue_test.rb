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

    test "leads_to topic chain shows hint" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about rumors", :return)
      assert_text "lurking in the cellar"
      assert_text "You could ask about: cellar."
    end

    test "leads_to locked subtopic shows locked_text" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Try cellar without asking about rumors first
      find(".terminal-input").send_keys("talk to innkeeper about cellar", :return)
      assert_text "What cellar?"
    end

    test "leads_to unlocked subtopic shows text" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Ask about rumors to unlock cellar
      find(".terminal-input").send_keys("talk to innkeeper about rumors", :return)
      assert_text "lurking in the cellar"

      # Now cellar should be accessible
      find(".terminal-input").send_keys("talk to innkeeper about cellar", :return)
      assert_text "cellar entrance is behind the bar"
    end

    test "keyword matching works for topic" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      # Use keyword "gossip" instead of topic key "rumors"
      find(".terminal-input").send_keys("talk to innkeeper about gossip", :return)
      assert_text "lurking in the cellar"
    end

    test "no keyword match returns doesn't know message" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to tavern
      find(".terminal-input").send_keys("go east", :return)
      assert_text "The Tavern"

      find(".terminal-input").send_keys("talk to innkeeper about dragons", :return)
      assert_text "doesn't know anything about that"
    end

    test "unknown topic shows doesn't know message" do
      visit dev_game_path
      find(".terminal-input").click

      # Go to market to test with merchant
      find(".terminal-input").send_keys("go west", :return)
      assert_text "The Market"

      find(".terminal-input").send_keys("talk to merchant about weather", :return)
      assert_text "doesn't know anything about that"
    end
  end
end
