# frozen_string_literal: true

# QA Test World — used by the debug game mode route (/dev/game).
# Minimal world with a single room to keep tests fast.

World.find_or_create_by!(name: "QA Test World") do |world|
  world.description = "A minimal world for QA / developer testing"
  world.world_data = {
    "meta" => {
      "starting_room" => "test_room",
      "version" => "1.0",
      "author" => "SuperTextAdventure"
    },
    "rooms" => {
      "test_room" => {
        "name" => "Test Chamber",
        "description" => "A bare stone chamber used for developer testing. Nothing of interest here.",
        "exits" => {},
        "items" => [],
        "npcs" => []
      }
    },
    "items" => {},
    "npcs" => {},
    "creatures" => {}
  }
end
