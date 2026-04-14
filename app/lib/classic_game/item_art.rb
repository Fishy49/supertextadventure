# frozen_string_literal: true

module ClassicGame
  module ItemArt
    CATEGORY_ART = {
      "weapon" => "  /|\n / |\n/  |\n===+",
      "potion" => "  _\n (*)\n |_|",
      "key" => "--o\n |\n--",
      "scroll" => "/-~-\\\n| ~ |\n\\---/",
      "armor" => " /--\\\n| () |\n \\--/",
      "treasure" => " /\\\n/  \\\n\\**/\n \\/",
      "container" => "+----+\n|    |\n+----+",
      "tool" => " _\n|_|\n/ \\",
      "default" => "[item]"
    }.freeze

    ITEM_ART = {
      "old_key" => " _\n|_|-\n  |",
      "health_potion" => "  _\n (R)\n |_|",
      "enchanted_blade" => "  *|\n / |\n/~~|\n===+",
      "scroll" => "/~~~\\\n|rune|\n\\---/",
      "victory_crown" => " VVV\n/ * \\\n\\___/",
      "lockpick" => "  _\n |_|\n/ |",
      "gem" => " /\\\n<**>\n \\/",
      "supply_crate" => "+====+\n|>  <|\n+====+"
    }.freeze

    def self.art_for(item_id, item_def)
      ITEM_ART[item_id] || CATEGORY_ART[category_for(item_def)] || CATEGORY_ART["default"]
    end

    def self.category_for(item_def)
      item_def = item_def || {}
      return "weapon" if item_def["weapon_damage"]
      return "armor" if item_def["defense_bonus"]
      return "potion" if item_def["consumable"] && item_def.dig("combat_effect", "type") == "heal"

      keywords = item_def["keywords"] || []
      return "tool" if (keywords & %w[pick lockpick tool]).any?
      return "key" if keywords.include?("key")
      return "scroll" if keywords.include?("scroll")
      return "container" if item_def["is_container"]
      return "treasure" if (keywords & %w[crown gem]).any?

      "default"
    end
  end
end
