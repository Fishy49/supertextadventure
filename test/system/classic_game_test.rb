# frozen_string_literal: true

require "application_system_test_case"

class ClassicGameTest < ApplicationSystemTestCase
  test "debug mode loads" do
    visit dev_game_path
    assert_current_path(%r{/games/})
    assert_text "[ DEV ]"
  end

  test "initial room description" do
    visit dev_game_path
    assert_text "Test Chamber"
  end

  test "send look command" do
    visit dev_game_path
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Test Chamber"
  end

  test "unknown command" do
    visit dev_game_path
    find(".terminal-input").click
    find(".terminal-input").send_keys("xyzzy", :return)
    assert_text "I don't understand"
  end

  test "navigation command with no exits" do
    visit dev_game_path
    find(".terminal-input").click
    find(".terminal-input").send_keys("go north", :return)
    assert_text "can't go"
  end

  test "reset game" do
    visit dev_game_path
    assert_text "[ DEV ]"
    click_on "Reset Game"
    # Reset redirects to dev_game_path which then redirects to the new game page
    assert_current_path(%r{/games/})
    assert_text "Test Chamber"
  end
end
