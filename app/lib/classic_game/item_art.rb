# frozen_string_literal: true

module ClassicGame
  module ItemArt
    ART = {
      "sword" => "   /|\n  / |\n /  |\n/___/",
      "blade" => "  /\n |/\n  |\\\n  |_",
      "key" => " (O)--\n |___]",
      "potion" => "  _\n(/)\n|~|\n|_|",
      "shield" => "/---\\\n|[*]|\n\\---/",
      "scroll" => " ____\n(    )\n|-..-|",
      "crown" => "^v^v^\n|___|",
      "gem" => " /\\\n<  >\n \\/",
      "coin" => ".---.\n|($)|\n'---'"
    }.freeze

    GENERIC_ART = ".-----.\n|     |\n'-----'"

    def self.art_for(item_def)
      return GENERIC_ART unless item_def

      keywords = item_def["keywords"] || []
      keywords.each do |kw|
        return ART[kw] if ART.key?(kw)
      end

      GENERIC_ART
    end
  end
end
