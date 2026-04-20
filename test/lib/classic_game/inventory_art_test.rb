# frozen_string_literal: true

require "test_helper"

class InventoryArtTest < ActiveSupport::TestCase
  test "returns ascii_art from item_def when provided" do
    result = ClassicGame::InventoryArt.for("x", { "ascii_art" => "CUSTOM" })
    assert_equal "CUSTOM", result
  end

  test "falls back to catalog by item_id" do
    result = ClassicGame::InventoryArt.for("sword", {})
    assert_includes result, "|"
    assert_equal ClassicGame::InventoryArt::CATALOG["sword"], result
  end

  test "falls back to catalog by keyword" do
    result = ClassicGame::InventoryArt.for("katana", { "keywords" => ["sword"] })
    assert_equal ClassicGame::InventoryArt::CATALOG["sword"], result
  end

  test "returns DEFAULT_ART when nothing matches" do
    result = ClassicGame::InventoryArt.for("zz_unknown", {})
    assert_equal ClassicGame::InventoryArt::DEFAULT_ART, result
  end

  test "returns DEFAULT_ART when item_def is nil" do
    result = ClassicGame::InventoryArt.for("zz_unknown")
    assert_equal ClassicGame::InventoryArt::DEFAULT_ART, result
  end

  test "ascii_art from item_def takes precedence over catalog entry" do
    result = ClassicGame::InventoryArt.for("sword", { "ascii_art" => "MY SWORD ART" })
    assert_equal "MY SWORD ART", result
  end

  test "keyword fallback checks all keywords in order" do
    result = ClassicGame::InventoryArt.for("flask", { "keywords" => %w[flask potion] })
    assert_equal ClassicGame::InventoryArt::CATALOG["potion"], result
  end
end
