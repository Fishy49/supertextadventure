# frozen_string_literal: true

module ClassicGame
  module Handlers
    class ExamineHandler < BaseHandler
      def handle(command)
        case command[:verb]
        when :look
          handle_look(command[:target])
        when :examine
          handle_examine(command[:target])
        when :inventory
          handle_inventory
        else
          failure("I don't understand that command.")
        end
      end

      private

      def handle_look(target)
        if target.nil? || target.empty?
          # Look at current room
          describe_current_room
        else
          # Look at specific thing
          handle_examine(target)
        end
      end

      def handle_examine(target)
        return failure("Examine what?") unless target

        # Try to find in room items
        item_id, item_def = find_item(target)
        if item_def && item_in_room?(item_id)
          return success(item_def["description"] || "You see nothing special about the #{item_def['name']}.")
        end

        # Try to find in inventory
        if item_def && has_item?(item_id)
          return success(item_def["description"] || "You see nothing special about the #{item_def['name']}.")
        end

        # Try to find NPC
        npc_id, npc_def = find_npc(target)
        if npc_def && npc_in_room?(npc_id)
          return success(npc_def["description"] || "You see #{npc_def['name']}.")
        end

        # Check if it's a room feature mentioned in description
        if current_room_def["description"]&.downcase&.include?(target)
          return success("You see nothing special about that.")
        end

        failure("You don't see that here.")
      end

      def handle_inventory
        inventory = player_state["inventory"] || []

        if inventory.empty?
          return success("You are carrying nothing.")
        end

        lines = ["You are carrying:"]
        inventory.each do |item_id|
          item_name = world_snapshot.dig("items", item_id, "name") || item_id
          lines << "  - #{item_name}"
        end

        success(lines.join("\n"))
      end

      def describe_current_room
        room_def = current_room_def
        return failure("Error: Current room not found.") unless room_def

        lines = []

        # Room name
        lines << "=== #{room_def['name']} ==="
        lines << ""

        # Room description
        lines << room_def["description"]

        # List visible items
        visible_items = current_room_state["items"] || []
        if visible_items.any?
          lines << ""
          item_names = visible_items.map { |item_id| world_snapshot.dig("items", item_id, "name") || item_id }
          lines << "You see: #{item_names.join(', ')}"
        end

        # List NPCs
        npcs = current_room_state["npcs"] || []
        if npcs.any?
          lines << ""
          npc_names = npcs.map { |npc_id| world_snapshot.dig("npcs", npc_id, "name") || npc_id }
          lines << "Present: #{npc_names.join(', ')}"
        end

        # List exits
        exits = room_def["exits"] || {}
        if exits.any?
          lines << ""
          lines << "Exits: #{exits.keys.map(&:to_s).map(&:upcase).join(', ')}"
        end

        success(lines.join("\n"))
      end
    end
  end
end
