# frozen_string_literal: true

module ClassicGame
  # The worlds shipped in games/, offered by the builder's Load menu.
  module SampleWorlds
    GAMES_DIR = Rails.root.join("games")

    BLANK = {
      "meta" => {
        "name" => "Untitled Adventure", "description" => "A brand new world.",
        "starting_room" => "start", "version" => "1.0"
      },
      "rooms" => {
        "start" => {
          "name" => "Starting Room",
          "description" => "You are standing in an empty room. It is waiting for you to describe it.",
          "exits" => {}, "items" => [], "npcs" => [], "creatures" => []
        }
      },
      "items" => {}, "npcs" => {}, "creatures" => {}
    }.freeze

    def self.all
      shipped = GAMES_DIR.glob("*.json").sort.filter_map do |file|
        world = JSON.parse(File.read(file))
        next unless world.is_a?(Hash) && world["meta"].is_a?(Hash)

        {
          "key" => file.basename(".json").to_s,
          "name" => world.dig("meta", "name") || file.basename(".json").to_s.humanize,
          "description" => world.dig("meta", "description").to_s.truncate(90),
          "world" => world
        }
      rescue JSON::ParserError
        nil
      end
      blank = { "key" => "blank", "name" => "Blank world", "description" => "One starting room and nothing else",
                "world" => BLANK }
      shipped + [blank]
    end
  end
end
