# frozen_string_literal: true

module ClassicGame
  # The text a player sees when a game begins: the starting room, what is in
  # it, and its exits. Shared by the Game model and the headless CLI.
  module StartingRoom
    module_function

    def describe(game)
      world = game.world_snapshot
      starting_room_id = world.dig("meta", "starting_room") || world["rooms"]&.keys&.first
      room_def = world.dig("rooms", starting_room_id)
      return "Error: Starting room not found." unless room_def

      room_state = game.room_state(starting_room_id)
      lines = ["=== #{room_def['name']} ===", "", room_def["description"]]
      lines.concat(listing("You see", room_state["items"], world["items"]))
      lines.concat(listing("Present", room_state["npcs"], world["npcs"]))
      lines.concat(listing("Creatures", room_state["creatures"], world["creatures"]))

      exits = room_def["exits"] || {}
      lines.push("", "Exits: #{exits.keys.map { |k| k.to_s.upcase }.join(', ')}") if exits.any?
      lines.push("", "Type HELP for available commands.")
      lines.join("\n")
    end

    def listing(label, ids, definitions)
      ids = Array(ids)
      return [] if ids.empty?

      names = ids.map { |id| definitions&.dig(id, "name") || id }
      ["", "#{label}: #{names.join(', ')}"]
    end
  end
end
