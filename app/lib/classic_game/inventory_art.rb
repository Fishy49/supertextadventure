# frozen_string_literal: true

module ClassicGame
  module InventoryArt
    DEFAULT_ART = <<~ART.freeze
      +--------+
      |  ITEM  |
      +--------+
    ART

    CATALOG = {
      "sword" => <<~ART.freeze,
           /|
          / |
         /  |
        /===|
       /    |
      |_____|
      ART
      "key" => <<~ART.freeze,
         ___
        /   \
        \___/
          |---+
          |---+
      ART
      "rusty_key" => <<~ART.freeze,
         ~~~
        /~~~\
        \~~~/
          |---+
          |---+
      ART
      "potion" => <<~ART.freeze,
          .---.
         /     \
        |  o o  |
        |   ~   |
         \     /
          `---'
      ART
      "health_potion" => <<~ART.freeze,
          .---.
         /  +  \
        |  + +  |
        |   +   |
         \     /
          `---'
      ART
      "scroll" => <<~ART.freeze,
        .======.
        | .... |
        | .... |
        | .... |
        `======'
      ART
      "chest" => <<~ART.freeze,
        .--------.
        |========|
        |  [__]  |
        `--------'
      ART
      "gold_coin" => <<~ART.freeze
          .---.
         /  $  \
        |  $ $  |
         \  $  /
          `---'
      ART
    }.freeze

    def self.for(item_id, item_def = nil)
      item_def = item_def || {}
      return item_def["ascii_art"] if item_def["ascii_art"].present?

      id_str = item_id.to_s
      return CATALOG[id_str] if CATALOG.key?(id_str)

      keywords = item_def["keywords"] || []
      keyword_match = keywords.find { |kw| CATALOG.key?(kw.to_s) }
      return CATALOG[keyword_match.to_s] if keyword_match

      DEFAULT_ART
    end
  end
end
