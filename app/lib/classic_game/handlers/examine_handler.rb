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
          description = item_def["description"] || "You see nothing special about the #{item_def['name']}."

          # Check if examining reveals an exit
          if item_def["on_examine"]&.dig("reveals_exit")
            return handle_examine_reveals_exit(item_def, description)
          end

          return success(description)
        end

        # Try to find in inventory
        if item_def && has_item?(item_id)
          description = item_def["description"] || "You see nothing special about the #{item_def['name']}."

          # Check if examining reveals an exit (can work from inventory too)
          if item_def["on_examine"]&.dig("reveals_exit")
            return handle_examine_reveals_exit(item_def, description)
          end

          return success(description)
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

      def handle_examine_reveals_exit(item_def, base_description)
        on_examine = item_def["on_examine"]
        direction = on_examine["reveals_exit"]
        reveal_text = on_examine["text"] || base_description

        # Check if exit exists in current room
        exit_data = current_room_def.dig("exits", direction.to_s) || current_room_def.dig("exits", direction.to_sym)

        # If exit doesn't exist, just show the description
        return success(base_description) unless exit_data

        # Check if already revealed
        if game.exit_revealed?(player_state["current_room"], direction)
          return success(base_description)
        end

        # Reveal the exit
        game.reveal_exit(player_state["current_room"], direction)

        # Build response with reveal message
        lines = [reveal_text]

        if exit_data.is_a?(Hash) && exit_data["reveal_msg"]
          lines << ""
          lines << exit_data["reveal_msg"]
        end

        success(lines.join("\n"))
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

        # List exits (filter out hidden unrevealed exits)
        exits = room_def["exits"] || {}
        room_id = player_state["current_room"]
        visible_exits = exits.select do |direction, exit_data|
          if exit_data.is_a?(Hash) && exit_data["hidden"]
            # Check if revealed
            game.exit_revealed?(room_id, direction.to_s)
          else
            true
          end
        end

        if visible_exits.any?
          lines << ""

          # Check if any exits have unlocked messages to show
          exit_descriptions = []
          visible_exits.each do |direction, exit_data|
            if exit_data.is_a?(Hash)
              # Check if this exit has been unlocked and has an unlocked_msg
              if exit_data["unlocked_msg"].present? && game.exit_unlocked?(room_id, direction.to_s)
                exit_descriptions << exit_data["unlocked_msg"]
              end
            end
          end

          # Show exit descriptions if any
          if exit_descriptions.any?
            exit_descriptions.each { |desc| lines << desc }
            lines << ""
          end

          lines << "Exits: #{visible_exits.keys.map(&:to_s).map(&:upcase).join(', ')}"
        end

        success(lines.join("\n"))
      end
    end
  end
end
