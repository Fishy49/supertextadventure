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
end
