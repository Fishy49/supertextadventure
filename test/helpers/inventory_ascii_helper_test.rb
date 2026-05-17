# frozen_string_literal: true

require "test_helper"

class InventoryAsciiHelperTest < ActionView::TestCase
  include InventoryAsciiHelper

  # ─── inventory_category_for ─────────────────────────────────────────────────

  test "explicit category is used when recognised" do
    item_def = { "category" => "crown", "weapon_damage" => 5 }
    assert_equal "crown", inventory_category_for(item_def)
  end

  test "explicit category is ignored when unrecognised" do
    item_def = { "category" => "mystery_meat" }
    assert_equal "generic", inventory_category_for(item_def)
  end

  test "is_container inferred as container" do
    item_def = { "is_container" => true }
    assert_equal "container", inventory_category_for(item_def)
  end

  test "weapon_damage inferred as weapon" do
    item_def = { "weapon_damage" => 3 }
    assert_equal "weapon", inventory_category_for(item_def)
  end

  test "defense_bonus inferred as armor" do
    item_def = { "defense_bonus" => 2 }
    assert_equal "armor", inventory_category_for(item_def)
  end

  test "combat_effect heal inferred as potion" do
    item_def = { "combat_effect" => { "type" => "heal", "amount" => 5 } }
    assert_equal "potion", inventory_category_for(item_def)
  end

  test "on_use message inferred as scroll" do
    item_def = { "on_use" => { "type" => "message", "text" => "Words appear." } }
    assert_equal "scroll", inventory_category_for(item_def)
  end

  test "on_use unlock inferred as key" do
    item_def = { "on_use" => { "type" => "unlock" } }
    assert_equal "key", inventory_category_for(item_def)
  end

  test "empty hash falls back to generic" do
    assert_equal "generic", inventory_category_for({})
  end

  # ─── inventory_ascii_for ────────────────────────────────────────────────────

  test "explicit ascii_art is returned verbatim" do
    item_def = { "ascii_art" => "  *\n ***\n  *" }
    assert_equal "  *\n ***\n  *", inventory_ascii_for(item_def)
  end

  test "returns a non-blank string for an item with no ascii_art" do
    item_def = {}
    result = inventory_ascii_for(item_def)
    assert result.present?, "Expected a non-blank ascii art string for generic fallback"
  end

  test "weapon category renders without error" do
    item_def = { "weapon_damage" => 5 }
    result = inventory_ascii_for(item_def)
    assert result.present?, "Expected ascii art for weapon"
  end

  test "potion category renders without error" do
    item_def = { "combat_effect" => { "type" => "heal" } }
    result = inventory_ascii_for(item_def)
    assert result.present?, "Expected ascii art for potion"
  end
end
