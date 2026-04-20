# frozen_string_literal: true

module ClassicGame
  module InventoryArt
    DEFAULT_ART = <<~ART
      +--------+
      |  ITEM  |
      +--------+
    ART

    CATALOG = {
      "sword" => <<~ART,
             /|
            / |
           /  |
          /===|
         /    |
        |_____|
      ART
      "key" => <<~ART,
           ___
          /   \
          ___/
            |---+
            |---+
      ART
      "rusty_key" => <<~ART,
           ~~~
          /~~~\
          ~~~/
            |---+
            |---+
      ART
      "potion" => <<~ART,
          .---.
         /     \
        |  o o  |
        |   ~   |
              /
          `---'
      ART
      "health_potion" => <<~ART,
          .---.
         /  +  \
        |  + +  |
        |   +   |
              /
          `---'
      ART
      "scroll" => <<~ART,
        .======.
        | .... |
        | .... |
        | .... |
        `======'
      ART
      "chest" => <<~ART,
        .--------.
        |========|
        |  [__]  |
        `--------'
      ART
      "gold_coin" => <<~ART
          .---.
         /  $  \
        |  $ $  |
           $  /
          `---'
      ART
    }.freeze

    def self.for(item_id, item_def = nil)
      item_def ||= {}
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
