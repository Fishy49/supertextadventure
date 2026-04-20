# frozen_string_literal: true

require "application_system_test_case"

class CrazyInventoryTest < ApplicationSystemTestCase
  # AC3 — Visually more appealing
  test "renders inventory header and dashed card per item" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("take key", :return)
    within("[id^='player_inventory_']") { assert_text "Rusty Key" }

    within("[id^='player_inventory_']") do
      assert_text "[[ INVENTORY ]]"
      assert_selector "li[data-item-id]"
      assert_selector "pre[data-inventory-target='art']", visible: false
    end
  end

  # AC2 — Click/tap reveals ascii art and detailed description
  test "clicking an inventory item reveals ascii art and detailed description" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("take key", :return)
    within("[id^='player_inventory_']") { assert_text "Rusty Key" }

    within("[id^='player_inventory_']") do
      assert_selector "pre[data-inventory-target='art']", visible: :hidden

      click_on "Rusty Key"

      assert_selector "pre[data-inventory-target='art']", visible: :visible
      assert_selector "p[data-inventory-target='description']", visible: :visible
    end
  end

  # AC2 — Clicking again collapses the item
  test "clicking an expanded item collapses it" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("take key", :return)
    within("[id^='player_inventory_']") { assert_text "Rusty Key" }

    within("[id^='player_inventory_']") do
      click_on "Rusty Key"
      assert_selector "pre[data-inventory-target='art']", visible: :visible

      click_on "Rusty Key"
      assert_selector "pre[data-inventory-target='art']", visible: :hidden
    end
  end

  # AC2 — Opening a second item collapses the first
  test "opening a second item collapses the first" do
    visit dev_game_path
    find(".terminal-input").click

    find(".terminal-input").send_keys("take key", :return)
    within("[id^='player_inventory_']") { assert_text "Rusty Key" }

    find(".terminal-input").send_keys("go east", :return)
    assert_text "The Tavern"

    find(".terminal-input").send_keys("take lockpick", :return)
    within("[id^='player_inventory_']") { assert_text "Lockpick" }

    within("[id^='player_inventory_']") do
      key_li = find("li[data-item-id='rusty_key']")
      pick_li = find("li[data-item-id='lockpick']")

      key_li.click_on "Rusty Key"
      assert_selector "li[data-item-id='rusty_key'] pre[data-inventory-target='art']", visible: :visible

      pick_li.click_on "Lockpick"
      assert_selector "li[data-item-id='lockpick'] pre[data-inventory-target='art']", visible: :visible
      assert_selector "li[data-item-id='rusty_key'] pre[data-inventory-target='art']", visible: :hidden
    end
  end

  # AC4 — Works in single + multiplayer (scoped wrapper per user)
  test "partial renders per-user scoped wrapper" do
    visit dev_game_path
    assert_selector "[id^='player_inventory_']"
  end
end
