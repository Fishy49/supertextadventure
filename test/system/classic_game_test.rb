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
    assert_text "Town Square"
  end

  test "send look command" do
    visit dev_game_path
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Town Square"
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
    find(".terminal-input").send_keys("go northeast", :return)
    assert_text "can't go"
  end

  test "reset game" do
    visit dev_game_path
    assert_text "[ DEV ]"
    click_on "Reset Game"
    # Reset redirects to dev_game_path which then redirects to the new game page
    assert_current_path(%r{/games/})
    assert_text "Town Square"
  end

  # AC1 — Inventory section appears in sidebar on load
  test "sidebar shows inventory section for classic game" do
    visit dev_game_path
    assert_selector "[id^='player_inventory_']"
    within("[id^='player_inventory_']") do
      assert_text "INVENTORY"
      assert_text "(empty)"
    end
  end

  # AC2 — Sidebar inventory updates in real-time as items are added/removed
  test "sidebar inventory updates when player takes and drops items" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("take key", :return)
    within("[id^='player_inventory_']") do
      assert_text "Rusty Key"
    end

    find(".terminal-input").send_keys("drop key", :return)
    within("[id^='player_inventory_']") do
      assert_text "(empty)"
      assert_no_text "Rusty Key"
    end
  end

  # AC3 — Inventory shortcuts show client-only hint and do not create game messages
  test "inventory shortcuts show client-only hint and do not create game messages" do
    visit dev_game_path
    find(".terminal-input").click
    initial_count = Message.count

    find(".terminal-input").send_keys("i", :return)
    assert_text "Your inventory is shown in the sidebar."

    find(".terminal-input").send_keys("inv", :return)
    assert_text "Your inventory is shown in the sidebar."

    find(".terminal-input").send_keys("inventory", :return)
    assert_text "Your inventory is shown in the sidebar."

    assert_equal initial_count, Message.count
  end

  # AC4 — Sidebar inventory is visible across commands and room changes
  test "sidebar inventory is visible across commands and room changes" do
    visit dev_game_path
    find(".terminal-input").click

    # Each command waits for its specific response text before the next one is
    # sent — commands are processed async and sending without a wait races the
    # job queue against the broadcast that updates the sidebar.
    assert_selector "[id^='player_inventory_']", visible: :visible

    find(".terminal-input").send_keys("take key", :return)
    assert_text "Rusty Key"

    find(".terminal-input").send_keys("go east", :return)
    assert_text "The Tavern"

    find(".terminal-input").send_keys("open chest", :return)
    assert_text "unlock the chest"

    find(".terminal-input").send_keys("take potion", :return)
    assert_text "Health Potion"

    within("[id^='player_inventory_']") do
      assert_text "Rusty Key"
      assert_text "Health Potion"
    end
  end
end
