# frozen_string_literal: true

require "test_helper"

class ItemArtTest < ActiveSupport::TestCase
  # ─── category_for ────────────────────────────────────────────────────────────

  test "category_for returns weapon for weapon_damage items" do
    assert_equal "weapon", ClassicGame::ItemArt.category_for("weapon_damage" => 3)
  end

  test "category_for returns armor for defense_bonus items" do
    assert_equal "armor", ClassicGame::ItemArt.category_for("defense_bonus" => 2)
  end

  test "category_for returns potion for consumable heal items" do
    item_def = { "consumable" => true, "combat_effect" => { "type" => "heal", "amount" => 5 } }
    assert_equal "potion", ClassicGame::ItemArt.category_for(item_def)
  end

  test "category_for returns key when keywords include key" do
    assert_equal "key", ClassicGame::ItemArt.category_for("keywords" => %w[brass key])
  end

  test "category_for returns scroll when keywords include scroll" do
    assert_equal "scroll", ClassicGame::ItemArt.category_for("keywords" => %w[ancient scroll])
  end

  test "category_for returns container for is_container items" do
    assert_equal "container", ClassicGame::ItemArt.category_for("is_container" => true)
  end

  test "category_for returns treasure when keywords include crown" do
    assert_equal "treasure", ClassicGame::ItemArt.category_for("keywords" => %w[crown victory])
  end

  test "category_for returns treasure when keywords include gem" do
    assert_equal "treasure", ClassicGame::ItemArt.category_for("keywords" => %w[gem glowing])
  end

  test "category_for returns default for unknown items" do
    assert_equal "default", ClassicGame::ItemArt.category_for("name" => "Mystery Box")
  end

  test "category_for handles nil item_def" do
    assert_equal "default", ClassicGame::ItemArt.category_for(nil)
  end

  # ─── art_for ─────────────────────────────────────────────────────────────────

  test "art_for returns non-empty string for weapon item" do
    result = ClassicGame::ItemArt.art_for("anything", "weapon_damage" => 1)
    assert result.present?
  end

  test "art_for returns weapon art for weapon_damage items" do
    result = ClassicGame::ItemArt.art_for("sword", "weapon_damage" => 3)
    assert_equal ClassicGame::ItemArt::CATEGORY_ART["weapon"], result
  end

  test "art_for falls back to default for unknown items" do
    result = ClassicGame::ItemArt.art_for("mystery", "name" => "Mystery")
    assert_equal ClassicGame::ItemArt::CATEGORY_ART["default"], result
  end

  test "art_for handles nil item_def" do
    result = ClassicGame::ItemArt.art_for("unknown", nil)
    assert_equal ClassicGame::ItemArt::CATEGORY_ART["default"], result
  end

  # ─── ITEM_ART per-item entries ────────────────────────────────────────────────

  test "ITEM_ART has entry for old_key" do
    result = ClassicGame::ItemArt::ITEM_ART["old_key"]
    assert_not_nil result, "ITEM_ART should have an entry for old_key"
    assert result.include?("\n"), "old_key art should be multi-line"
  end

  test "ITEM_ART has entry for health_potion" do
    assert_not_nil ClassicGame::ItemArt::ITEM_ART["health_potion"]
  end

  test "ITEM_ART has entry for enchanted_blade" do
    assert_not_nil ClassicGame::ItemArt::ITEM_ART["enchanted_blade"]
  end

  test "ITEM_ART has entry for victory_crown" do
    assert_not_nil ClassicGame::ItemArt::ITEM_ART["victory_crown"]
  end

  test "art_for prefers ITEM_ART over CATEGORY_ART for old_key" do
    item_def = { "keywords" => ["key"] }
    result = ClassicGame::ItemArt.art_for("old_key", item_def)
    assert_equal ClassicGame::ItemArt::ITEM_ART["old_key"], result,
                 "art_for should return ITEM_ART entry, not CATEGORY_ART key art"
  end

  # ─── category_for tool category ───────────────────────────────────────────────

  test "category_for returns tool for lockpick keywords" do
    item_def = { "keywords" => %w[lockpick pick] }
    assert_equal "tool", ClassicGame::ItemArt.category_for(item_def)
  end

  test "category_for returns tool for pick keyword" do
    item_def = { "keywords" => %w[pick metal] }
    assert_equal "tool", ClassicGame::ItemArt.category_for(item_def)
  end

  test "CATEGORY_ART has entry for tool" do
    assert_not_nil ClassicGame::ItemArt::CATEGORY_ART["tool"],
                   "CATEGORY_ART should have a tool entry"
  end
end
