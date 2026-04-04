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
          exit_data["unlocked_msg"]
          permanently_unlock = exit_data["permanently_unlock"]
          hidden = exit_data["hidden"]

          # Check if exit is hidden and not yet revealed
          if hidden && direction && !game.exit_revealed?(player_state["current_room"], direction)
            # Check if it should be auto-revealed by flag
            return failure("You can't go that way.") unless requires_flag && game.get_flag(requires_flag)

            game.reveal_exit(player_state["current_room"], direction)
          end

          # Check if exit is permanently unlocked
          if permanently_unlock && direction && game.exit_unlocked?(player_state["current_room"], direction)
            # Already unlocked, can pass through
            return move_to_room(destination)
          end

          # Check if exit requires using an item on it (interactive unlocking)
          use_item = exit_data["use_item"]
          if use_item.present? && !(direction && game.exit_unlocked?(player_state["current_room"], direction))
            # Exit requires interactive unlocking - check if it's been unlocked
            return failure(locked_msg)
          end

          # Check flag requirement
          return failure(locked_msg) if requires_flag && !game.get_flag(requires_flag)

          # Check inventory requirement
          return failure(locked_msg) if requires && !item?(requires)

          # All checks passed, can move
          move_to_room(destination)
        end

        def move_to_room(room_id)
          new_room_def = world_snapshot.dig("rooms", room_id)
          return failure("Error: Room '#{room_id}' not found.") unless new_room_def

          first_visit = !player_state["visited_rooms"]&.include?(room_id)
          old_room_id = player_state["current_room"]

          # Collect players in old room before moving (to notify of departure)
          old_room_others = other_players_in_room

          # Update player state
          new_state = player_state.dup
          new_state["current_room"] = room_id
          new_state["visited_rooms"] ||= []
          new_state["visited_rooms"] << room_id unless new_state["visited_rooms"].include?(room_id)

          new_state["room_entries"] ||= {}
          new_state["room_entries"][room_id] = (new_state["room_entries"][room_id] || 0) + 1

          update_player_state(new_state)

          # Collect players in new room after moving (to notify of arrival)
          new_room_others = other_players_in_room

          # Generate room description
          description = generate_room_description(room_id, new_room_def, first_visit)

          # Build secondary messages for room transition notifications
          secondary = build_movement_notifications(old_room_id, old_room_others, room_id, new_room_others)

          result = success(description, state_changes: { moved: true, room: room_id })
          result[:secondary_messages] = secondary if secondary.any?
          result
        end

        def generate_room_description(room_id, room_def, first_visit)
          lines = []

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

          # List creatures
          creatures = room_state["creatures"] || []
          if creatures.any?
            lines << ""
            creature_names = creatures.map do |creature_id|
              world_snapshot.dig("creatures", creature_id, "name") || creature_id
            end
            lines << "Creatures: #{creature_names.join(', ')}"
          end

          # List other players in the room
          other_player_ids = other_players_in_room
          if other_player_ids.any? && game.respond_to?(:game_users)
            player_names = other_player_ids.filter_map do |pid|
              gu = game.game_users.find { |u| u.user_id.to_s == pid.to_s }
              gu&.character_name
            end
            if player_names.any?
              lines << ""
              lines << "Also here: #{player_names.join(', ')}"
            end
          end

          lines.concat(generate_exits_lines(room_id, room_def))

          lines.join("\n")
        end

        def generate_exits_lines(room_id, room_def)
          exits = room_def["exits"] || {}
          visible_exits = exits.select do |direction, exit_data|
            if exit_data.is_a?(Hash) && exit_data["hidden"]
              game.exit_revealed?(room_id, direction.to_s)
            else
              true
            end
          end

          return [] unless visible_exits.any?

          lines = [""]

          exit_descriptions = []
          visible_exits.each do |direction, exit_data|
            next unless exit_data.is_a?(Hash)

            if exit_data["hidden"] && exit_data["reveal_msg"].present? && game.exit_revealed?(room_id, direction.to_s)
              exit_descriptions << exit_data["reveal_msg"]
            end

            if exit_data["unlocked_msg"].present? && game.exit_unlocked?(room_id, direction.to_s)
              exit_descriptions << exit_data["unlocked_msg"]
            end
          end

          if exit_descriptions.any?
            exit_descriptions.each { |desc| lines << desc }
            lines << ""
          end

          lines << "Exits: #{visible_exits.keys.map { |k| k.to_s.upcase }.join(', ')}"
          lines
        end

        def acting_character_name
          return nil unless game.respond_to?(:game_users)

          gu = game.game_users.find { |u| u.user_id.to_s == user_id.to_s }
          gu&.character_name
        end

        def build_movement_notifications(_old_room_id, old_room_others, _new_room_id, new_room_others)
          secondary = []
          char_name = acting_character_name

          if char_name && old_room_others.any?
            secondary << { text: "#{char_name} has left.", visible_to: old_room_others }
          end

          if char_name && new_room_others.any?
            secondary << { text: "#{char_name} has arrived.", visible_to: new_room_others }
          end

          secondary
        end
    end
  end
end
