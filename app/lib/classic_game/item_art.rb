# frozen_string_literal: true

module ClassicGame
  module ItemArt
    CATEGORY_ART = {
      "weapon" => "  /|\n / |\n/  |\n===+",
      "potion" => "  _\n (*)\n |_|",
      "key" => "--o\n |\n--",
      "scroll" => "/-~-\\\n| ~ |\n\\---/",
      "armor" => " /--\\\n| () |\n \\--/",
      "shield" => " _\n[#]\n|_|",
      "treasure" => " /\\\n/  \\\n\\**/\n \\/",
      "container" => "+----+\n|    |\n+----+",
      "default" => "[item]"
    }.freeze

    ICON_MAP = {
      "weapon" => "/|\\",
      "potion" => "(*)",
      "key" => "-o-",
      "scroll" => "~=~",
      "armor" => "[+]",
      "shield" => "[#]",
      "treasure" => "<*>",
      "container" => "[=]",
      "default" => " * "
    }.freeze

    ITEM_ART = {
      "old_key" => " _\n|o|\n '--",
      "health_potion" => "  _\n (+)\n |H|",
      "enchanted_blade" => "  *\n /|\n/ |\n===",
      "victory_crown" => " /\\*\\/\\\n( *** )\n \\___/"
    }.freeze

    def self.art_for(item_id, item_def)
      ITEM_ART[item_id] || CATEGORY_ART[category_for(item_def)] || CATEGORY_ART["default"]
    end

    def self.icon_for(item_id, item_def)
      ICON_MAP[category_for(item_def)]
    end

    def self.category_for(item_def)
      item_def = item_def || {}
      return "weapon" if item_def["weapon_damage"]
      return "armor" if item_def["defense_bonus"]
      return "potion" if item_def["consumable"] && item_def.dig("combat_effect", "type") == "heal"
      return "key" if (item_def["keywords"] || []).include?("key")
      return "scroll" if (item_def["keywords"] || []).include?("scroll")
      return "shield" if (item_def["keywords"] || []).include?("shield")
      return "container" if item_def["is_container"]
      return "treasure" if ((item_def["keywords"] || []) & %w[crown gem]).any?

      "default"
    end
  end
end
