# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class InventoryTest < ApplicationSystemTestCase
    test "inventory shows enhanced display with header and footer" do
      visit dev_game_path
      find(".terminal-input").click

      # Take the rusty key so inventory is non-empty
      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("inventory", :return)
      assert_text "=== INVENTORY ==="
      assert_text "Rusty Key"

      # Click the inventory item to expand hidden detail
      find(".inventory-item", text: "Rusty Key").click
      assert_text "EXAMINE"
    end

    test "inventory shows key art for key item" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("take key", :return)
      assert_text "Rusty Key"

      find(".terminal-input").send_keys("inventory", :return)
      assert_text "=== INVENTORY ==="

      # Click the inventory item to expand and reveal art
      find(".inventory-item", text: "Rusty Key").click
      assert_text "(   )"
    end

    test "inventory shows custom art for magic wand" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go west", :return)
      assert_text "The Market"

      find(".terminal-input").send_keys("take wand", :return)
      assert_text "Magic Wand"

      find(".terminal-input").send_keys("inventory", :return)
      assert_text "=== INVENTORY ==="
      assert_text "Magic Wand"

      # Click the inventory item to expand and reveal art
      find(".inventory-item", text: "Magic Wand").click
      assert_text "***"
    end
  end
end
