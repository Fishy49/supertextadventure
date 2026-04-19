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
    assert_button "Inventory"
    within("[id^='player_inventory_']") do
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
    assert_text "Thine inventory is innith thine sidebar!"

    find(".terminal-input").send_keys("inv", :return)
    assert_text "Thine inventory is innith thine sidebar!"

    find(".terminal-input").send_keys("inventory", :return)
    assert_text "Thine inventory is innith thine sidebar!"

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

  # AC5 — Sidebar tabs switch between Inventory and Players panels
  test "sidebar tabs switch between inventory and players panels" do
    visit dev_game_path
    find(".terminal-input").click

    # Inventory tab is the default — inventory is visible, players list is hidden.
    assert_selector "[id^='player_inventory_']", visible: :visible

    click_on "Players"
    assert_selector "[id^='player_inventory_']", visible: :hidden
    assert_selector "turbo-frame#players", visible: :visible

    click_on "Inventory"
    assert_selector "[id^='player_inventory_']", visible: :visible
    assert_selector "turbo-frame#players", visible: :hidden
  end

  # AC6 — Clicking an inventory item expands/collapses its description
  test "clicking inventory item toggles its description" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("take key", :return)
    within("[id^='player_inventory_']") { assert_text "Rusty Key" }

    within("[id^='player_inventory_']") do
      # Description is hidden until the item is clicked.
      assert_no_text "rusty iron key"

      click_on "Rusty Key"
      assert_text "rusty iron key"

      # Clicking again collapses the description.
      click_on "Rusty Key"
      assert_no_text "rusty iron key"
    end
  end

  # AC7 — Client-side inventory hint clears when a new command is sent
  test "inventory hint clears when another command is sent" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("i", :return)
    assert_text "Thine inventory is innith thine sidebar!"

    find(".terminal-input").send_keys("look", :return)
    assert_text "Town Square"
    assert_no_text "Thine inventory is innith thine sidebar!"
  end

  # AC8 — Client-side inventory hint fades out after a few seconds on its own
  test "inventory hint auto-dismisses after a few seconds" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("i", :return)
    assert_text "Thine inventory is innith thine sidebar!"

    # Fade kicks in at 4s and finishes at ~4.5s; allow a generous wait.
    assert_no_text "Thine inventory is innith thine sidebar!", wait: 8
  end
end
