# frozen_string_literal: true

module ClassicGame
  module Handlers
    class MovementHandler < BaseHandler
      def handle(command)
        direction = command[:target]
        return failure("Go where?") unless direction

        # Get exit from current room
        exit_data = current_room_def.dig("exits", direction.to_s) || current_room_def.dig("exits", direction.to_sym)
        return failure("You can't go that way.") unless exit_data

        # Handle simple string exit vs. complex exit object
        if exit_data.is_a?(String)
          move_to_room(exit_data)
        elsif exit_data.is_a?(Hash)
          handle_complex_exit(exit_data, direction)
        else
          failure("Something is wrong with that exit.")
        end
      end

      private

      def handle_complex_exit(exit_data, direction = nil)
        destination = exit_data["to"]
        requires = exit_data["requires"]
        requires_flag = exit_data["requires_flag"]
        locked_msg = exit_data["locked_msg"] || "That way is blocked."
        unlocked_msg = exit_data["unlocked_msg"]
        permanently_unlock = exit_data["permanently_unlock"]
        hidden = exit_data["hidden"]
        reveal_msg = exit_data["reveal_msg"]

        # Check if exit is hidden and not yet revealed
        if hidden && direction
          unless game.exit_revealed?(player_state["current_room"], direction)
            # Check if it should be auto-revealed by flag
            if requires_flag && game.get_flag(requires_flag)
              game.reveal_exit(player_state["current_room"], direction)
              return success(reveal_msg) if reveal_msg
            else
              return failure("You can't go that way.")
            end
          end
        end

        # Check if exit is permanently unlocked
        if permanently_unlock && direction && game.exit_unlocked?(player_state["current_room"], direction)
          # Already unlocked, show unlocked message if first time seeing it
          return move_to_room(destination, unlocked_msg)
        end

        # Check if exit requires using an item on it (interactive unlocking)
        use_item = exit_data["use_item"]
        if use_item.present?
          # Exit requires interactive unlocking - check if it's been unlocked
          unless direction && game.exit_unlocked?(player_state["current_room"], direction)
            return failure(locked_msg)
          end
        end

        # Check flag requirement
        if requires_flag && !game.get_flag(requires_flag)
          return failure(locked_msg)
        end

        # Check inventory requirement
        if requires && !has_item?(requires)
          return failure(locked_msg)
        end

        # All checks passed, can move
        move_to_room(destination, unlocked_msg)
      end

      def move_to_room(room_id, unlocked_msg = nil)
        new_room_def = world_snapshot.dig("rooms", room_id)
        return failure("Error: Room '#{room_id}' not found.") unless new_room_def

        first_visit = !player_state["visited_rooms"]&.include?(room_id)

        # Update player state
        new_state = player_state.dup
        new_state["current_room"] = room_id
        new_state["visited_rooms"] ||= []
        new_state["visited_rooms"] << room_id unless new_state["visited_rooms"].include?(room_id)

        update_player_state(new_state)

        # Generate room description
        description = generate_room_description(room_id, new_room_def, first_visit, unlocked_msg)

        success(description, state_changes: { moved: true, room: room_id })
      end

      def generate_room_description(room_id, room_def, first_visit, unlocked_msg = nil)
        lines = []

        # Show unlocked message if present
        if unlocked_msg
          lines << unlocked_msg
          lines << ""
        end

        # Room name
        lines << "=== #{room_def['name']} ==="
        lines << ""

        # Room description
        lines << room_def["description"]

        # Show on_enter message if first visit and exists
        if first_visit && room_def["on_enter"]
          on_enter = room_def["on_enter"]
          if on_enter.is_a?(Hash) && on_enter["type"] == "message"
            lines << ""
            lines << on_enter["text"]
          end
        end

        # List visible items
        room_state = game.room_state(room_id)
        visible_items = room_state["items"] || []
        if visible_items.any?
          lines << ""
          item_names = visible_items.map { |item_id| world_snapshot.dig("items", item_id, "name") || item_id }
          lines << "You see: #{item_names.join(', ')}"
        end

        # List NPCs
        npcs = room_state["npcs"] || []
        if npcs.any?
          lines << ""
          npc_names = npcs.map { |npc_id| world_snapshot.dig("npcs", npc_id, "name") || npc_id }
          lines << "Present: #{npc_names.join(', ')}"
        end

        # List exits (filter out hidden unrevealed exits)
        exits = room_def["exits"] || {}
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
          lines << "Exits: #{visible_exits.keys.map(&:to_s).map(&:upcase).join(', ')}"
        end

        lines.join("\n")
      end
    end
  end
end
