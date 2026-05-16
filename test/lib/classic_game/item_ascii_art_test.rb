# frozen_string_literal: true

require "test_helper"

class ItemAsciiArtTest < ActiveSupport::TestCase
  test "returns explicit ascii_art when present" do
    item_def = { "ascii_art" => "  X\n /|\\\n / \\", "name" => "Custom" }
    result = ClassicGame::ItemAsciiArt.for(item_def, "custom_thing")
    assert_equal "  X\n /|\\\n / \\", result
  end

  test "treats empty string ascii_art as absent and falls back" do
    item_def = { "ascii_art" => "", "name" => "Key", "keywords" => ["key"] }
    result = ClassicGame::ItemAsciiArt.for(item_def, "empty_art_key")
    assert_includes result, "___"
  end

  test "falls back by item_id substring" do
    item_def = { "name" => "Rusty Key", "keywords" => ["rusty"] }
    result = ClassicGame::ItemAsciiArt.for(item_def, "rusty_key")
    assert_includes result, "___"
  end

  test "falls back by keyword" do
    item_def = { "name" => "Excalibur", "keywords" => %w[sword blade] }
    result = ClassicGame::ItemAsciiArt.for(item_def, "excalibur")
    assert_includes result, "__||__"
  end

  test "returns default when no match" do
    item_def = { "name" => "Whatsit", "keywords" => ["whatsit"] }
    result = ClassicGame::ItemAsciiArt.for(item_def, "whatsit")
    assert_includes result, "?"
  end

  test "handles nil item_def gracefully" do
    result = ClassicGame::ItemAsciiArt.for({}, "unknown_thing")
    assert_includes result, "?"
  end

  test "fallback_for returns default when no candidates match" do
    result = ClassicGame::ItemAsciiArt.fallback_for("zork_artifact", [])
    assert_equal ClassicGame::ItemAsciiArt::FALLBACK_ART["default"], result
  end

  test "fallback_for matches partial item_id" do
    result = ClassicGame::ItemAsciiArt.fallback_for("old_sword_of_doom", [])
    assert_includes result, "__||__"
  end
end
