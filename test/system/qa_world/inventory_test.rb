# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class InventoryTest < ApplicationSystemTestCase
    test "inventory shows formatted header" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      find(".terminal-input").send_keys("inventory", :return)
      assert_text "=== INVENTORY ==="
    end

    test "inventory shows examine hint" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      find(".terminal-input").send_keys("inventory", :return)
      assert_text "Click an item for details"
    end

    test "examine inventory key shows description" do
      visit dev_game_path
      find(".terminal-input").click
      find(".terminal-input").send_keys("take key", :return)
      find(".terminal-input").send_keys("examine key", :return)
      assert_text "Rusty Key"
      assert_text "rusty iron key"
    end
  end
end
