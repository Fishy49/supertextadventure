# frozen_string_literal: true

module ClassicGame
  module ItemAsciiArt
    FALLBACK_ART = {
      "key" => "  ___\n /   |\n \\___|-o",
      "sword" => "   /\\\n  /  \\\n /----\\\n|__||__|\n   ||\n  _||_",
      "potion" => "  ___\n /   \\\n|     |\n|     |\n \\___/\n  | |",
      "scroll" => " _____\n|     |\n| --- |\n| --- |\n|_____|\n(_____)",
      "gem" => "  /\\\n /  \\\n\\    /\n >--<\n/    \\\n \\  /",
      "book" => " _____\n/     \\\n|=====|\n|     |\n|=====|\n\\_____/",
      "coin" => "  ___\n / $ \\\n|     |\n \\___/",
      "torch" => "  )\n )((\n  )(\n  ||\n  ||\n  ||",
      "shield" => " _____\n/     \\\n| ( ) |\n|     |\n \\   /\n  \\_/",
      "bottle" => "  ___\n |   |\n  \\ /\n  | |\n  | |\n  |_|",
      "ring" => "  ___\n /   \\\n(     )\n \\___/",
      "map" => " _____\n|  .  |\n| .X. |\n|  .  |\n|_____|\n[_____]",
      "gold" => "  $$$\n $$$$$\n$ $$$ $\n $$$$$\n  $$$",
      "helmet" => " _____\n/     \\\n| o o |\n|     |\n|_____|",
      "axe" => " ___\n/   \\\n| * |\\\n\\___/ \\\n      ||\n     _||_",
      "bow" => "  |\n  |\\\n  | \\\n  |  >\n  | /\n  |/",
      "food" => "  ___\n /   \\\n( ~~~ )\n \\___/",
      "chest" => " _____\n|=====|\n|     |\n|  $  |\n|_____|",
      "box" => " _____\n|     |\n|     |\n|     |\n|_____|",
      "default" => ".-----.\n|  ?  |\n'-----'"
    }.freeze

    def self.for(item_def, item_id)
      art = item_def.is_a?(Hash) ? item_def["ascii_art"] : nil
      return art if art.present?

      keywords = (item_def.is_a?(Hash) ? item_def["keywords"] : nil) || []
      fallback_for(item_id, keywords)
    end

    def self.fallback_for(item_id, keywords)
      candidates = [item_id.to_s, *keywords].compact.map { |s| s.to_s.downcase }
      FALLBACK_ART.each do |key, art|
        next if key == "default"
        return art if candidates.any? { |c| c.include?(key) }
      end
      FALLBACK_ART["default"]
    end
  end
end
