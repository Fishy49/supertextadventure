# frozen_string_literal: true

require "test_helper"

class InventoryArtHelperTest < ActionView::TestCase

  # ─── inventory_art_partial_for ───────────────────────────────────────────────

  test "returns inv_sword for item_id matching sword keyword" do
    assert_equal "inv_sword", inventory_art_partial_for("sword", {})
  end

  test "returns inv_sword when keywords include blade" do
    assert_equal "inv_sword", inventory_art_partial_for("weapon_01", { "keywords" => ["blade"] })
  end

  test "returns inv_key for item_id key" do
    assert_equal "inv_key", inventory_art_partial_for("key", {})
  end

  test "returns inv_key when keywords include key" do
    assert_equal "inv_key", inventory_art_partial_for("rusty_key", { "keywords" => ["key", "rusty"] })
  end

  test "returns inv_potion for item_id potion" do
    assert_equal "inv_potion", inventory_art_partial_for("potion", {})
  end

  test "returns inv_potion when keywords include flask" do
    assert_equal "inv_potion", inventory_art_partial_for("bottle", { "keywords" => ["flask"] })
  end

  test "returns inv_potion when keywords include elixir" do
    assert_equal "inv_potion", inventory_art_partial_for("brew", { "keywords" => ["elixir"] })
  end

  test "returns inv_scroll for item_id scroll" do
    assert_equal "inv_scroll", inventory_art_partial_for("scroll", {})
  end

  test "returns inv_scroll when keywords include parchment" do
    assert_equal "inv_scroll", inventory_art_partial_for("doc", { "keywords" => ["parchment"] })
  end

  test "returns inv_scroll when keywords include tome" do
    assert_equal "inv_scroll", inventory_art_partial_for("book", { "keywords" => ["tome"] })
  end

  test "returns inv_gem for item_id gem" do
    assert_equal "inv_gem", inventory_art_partial_for("gem", {})
  end

  test "returns inv_gem when keywords include crystal" do
    assert_equal "inv_gem", inventory_art_partial_for("shard", { "keywords" => ["crystal"] })
  end

  test "returns inv_gem when keywords include stone" do
    assert_equal "inv_gem", inventory_art_partial_for("pebble", { "keywords" => ["stone"] })
  end

  test "returns inv_crown for item_id crown" do
    assert_equal "inv_crown", inventory_art_partial_for("crown", {})
  end

  test "returns inv_crown when keywords include diadem" do
    assert_equal "inv_crown", inventory_art_partial_for("headpiece", { "keywords" => ["diadem"] })
  end

  test "returns inv_crown when keywords include circlet" do
    assert_equal "inv_crown", inventory_art_partial_for("ring", { "keywords" => ["circlet"] })
  end

  test "returns inv_chest for item_id chest" do
    assert_equal "inv_chest", inventory_art_partial_for("chest", {})
  end

  test "returns inv_chest when keywords include crate" do
    assert_equal "inv_chest", inventory_art_partial_for("box_01", { "keywords" => ["crate"] })
  end

  test "returns inv_chest when keywords include box" do
    assert_equal "inv_chest", inventory_art_partial_for("container", { "keywords" => ["box"] })
  end

  test "returns inv_chest when keywords include coffer" do
    assert_equal "inv_chest", inventory_art_partial_for("vault", { "keywords" => ["coffer"] })
  end

  test "returns inv_lockpick for item_id lockpick" do
    assert_equal "inv_lockpick", inventory_art_partial_for("lockpick", {})
  end

  test "returns inv_lockpick when keywords include pick" do
    assert_equal "inv_lockpick", inventory_art_partial_for("tool", { "keywords" => ["pick"] })
  end

  test "returns inv_generic when no keywords match" do
    assert_equal "inv_generic", inventory_art_partial_for("strange_artifact", { "keywords" => ["strange"] })
  end

  test "returns inv_generic for nil item_def" do
    assert_equal "inv_generic", inventory_art_partial_for("unknown_thing", nil)
  end

  test "returns inv_generic for empty item_def" do
    assert_equal "inv_generic", inventory_art_partial_for("widget", {})
  end

  # ─── ascii_art_partial override ─────────────────────────────────────────────

  test "honors ascii_art_partial override when valid" do
    item_def = { "ascii_art_partial" => "inv_gem", "keywords" => ["sword"] }
    assert_equal "inv_gem", inventory_art_partial_for("my_item", item_def)
  end

  test "ignores ascii_art_partial override with invalid characters" do
    item_def = { "ascii_art_partial" => "../../etc/passwd", "keywords" => ["sword"] }
    assert_equal "inv_sword", inventory_art_partial_for("my_item", item_def)
  end

  test "ignores ascii_art_partial override when not a string" do
    item_def = { "ascii_art_partial" => 42, "keywords" => ["gem"] }
    assert_equal "inv_gem", inventory_art_partial_for("my_item", item_def)
  end

  # ─── Case insensitivity ──────────────────────────────────────────────────────

  test "matches keyword case-insensitively" do
    assert_equal "inv_sword", inventory_art_partial_for("SWORD", { "keywords" => ["SWORD"] })
  end

  test "matches item_id case-insensitively" do
    assert_equal "inv_key", inventory_art_partial_for("KEY", {})
  end
end
