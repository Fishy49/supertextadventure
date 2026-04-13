# frozen_string_literal: true

module ClassicGame
  class InventoryArt
    ART = {
      "weapon" => <<~ART.chomp,
           |>
          /|
         / |
        /  |
        |__|
         ||
      ART
      "potion" => <<~ART.chomp,
          ,--.
         ( ~~ )
        |/~~~~\|
        |      |
         '----'
      ART
      "key" => <<~ART.chomp,
          ___
         (   )
          ---
           |
          _|_
      ART
      "scroll" => <<~ART.chomp,
          .---.
         (     )
         |~~~~~|
         (     )
          '---'
      ART
      "shield" => <<~ART.chomp,
          /--\
         /    \
        | |  | |
         \ -- /
          \--/
      ART
      "container" => <<~ART.chomp,
         _____
        |-----|
        |     |
        |_____|
      ART
      "crown" => <<~ART.chomp,
        |\ /\ /|
        | V  V |
        |      |
         \----/
      ART
      "gem" => <<~ART.chomp,
            /\
           /  \
          / <> \
        /________\
      ART
      "default" => <<~ART.chomp,
          ___
         /   \
        | bag |
        |     |
         \___/
      ART
    }.freeze

    def self.for(item_id, item_def)
      return item_def["art"] if item_def["art"].present?

      # Check keywords against category names
      keywords = item_def["keywords"] || []
      ART.each_key do |category|
        return ART[category] if keywords.any? do |kw|
          kw.downcase.include?(category) || category.include?(kw.downcase)
        end
      end

      # Semantic property fallbacks
      return ART["weapon"] if item_def["weapon_damage"].present?
      return ART["potion"] if item_def.dig("combat_effect", "type") == "heal"
      return ART["container"] if item_def["is_container"]

      ART["default"]
    end
  end
end
