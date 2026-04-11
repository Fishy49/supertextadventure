# frozen_string_literal: true

module ClassicGame
  module Handlers
    class MovementHandler < BaseHandler
      OPPOSITE_DIRECTIONS = {
        "north" => "south", "south" => "north",
        "east" => "west", "west" => "east",
        "up" => "down", "down" => "up",
        "northeast" => "southwest", "southwest" => "northeast",
        "northwest" => "southeast", "southeast" => "northwest"
      }.freeze

      def handle(command)
        direction = command[:target]
        return failure("Go where?") unless direction

        # Get exit from current room
        exit_data = current_room_def.dig("exits", direction.to_s) || current_room_def.dig("exits", direction.to_sym)
        return failure("You can't go that way.") unless exit_data

        # Handle simple string exit vs. complex exit object
        if exit_data.is_a?(String)
          move_to_room(exit_data, direction: direction.to_s)
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
            return move_to_room(destination, direction: direction.to_s)
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
          move_to_room(destination, direction: direction.to_s)
        end

        def move_to_room(room_id, direction: nil)
          new_room_def = world_snapshot.dig("rooms", room_id)
          return failure("Error: Room '#{room_id}' not found.") unless new_room_def

          old_room_id = player_state["current_room"]
          first_visit = !player_state["visited_rooms"]&.include?(room_id)

          # Capture players in the old room before the move (for departure notifications)
          departing_observers = other_players_in_room

          # Update player state
          new_state = player_state.dup
          new_state["current_room"] = room_id
          new_state["visited_rooms"] ||= []
          new_state["visited_rooms"] << room_id unless new_state["visited_rooms"].include?(room_id)

          new_state["room_entries"] ||= {}
          new_state["room_entries"][room_id] = (new_state["room_entries"][room_id] || 0) + 1

          update_player_state(new_state)

          # Capture players already in the new room (excludes moving player)
          arriving_observers = other_players_in_room

          # Generate room description (lists co-located players)
          description = generate_room_description(room_id, new_room_def, first_visit)

          # Build multiplayer notification texts
          player_name = game.character_name_for(user_id)
          state_changes = build_state_changes(room_id, old_room_id, direction, player_name,
                                              departing_observers, arriving_observers)

          success(description, state_changes: state_changes)
        end

        def build_state_changes(new_room_id, old_room_id, direction, player_name,
                                departing_observers, arriving_observers)
          changes = { moved: true, room: new_room_id }
          return changes unless player_name

          dir_str = direction.to_s
          opposite = OPPOSITE_DIRECTIONS[dir_str] || "another direction"

          if departing_observers.any?
            changes[:departed_room] = old_room_id
            changes[:departure_text] = "**#{player_name} heads #{dir_str}.**"
            changes[:departure_audience] = departing_observers.map { |uid, _| uid }
          end

          if arriving_observers.any?
            changes[:entered_room] = new_room_id
            changes[:arrival_text] = "**#{player_name} arrives from the #{opposite}.**"
            changes[:arrival_audience] = arriving_observers.map { |uid, _| uid }
          end

          changes
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

          # List other player characters in this room
          others = other_players_in_room
          if others.any?
            lines << ""
            names = others.map { |uid, _state| game.character_name_for(uid) || "Unknown" }
            lines << "Also here: #{names.join(', ')}"
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

            # Check if any exits have descriptive messages to show
            exit_descriptions = []
            visible_exits.each do |direction, exit_data|
              next unless exit_data.is_a?(Hash)

              # Show reveal_msg for revealed hidden exits
              if exit_data["hidden"] && exit_data["reveal_msg"].present? && game.exit_revealed?(room_id, direction.to_s)
                exit_descriptions << exit_data["reveal_msg"]
              end

              # Show unlocked_msg for unlocked exits
              if exit_data["unlocked_msg"].present? && game.exit_unlocked?(room_id, direction.to_s)
                exit_descriptions << exit_data["unlocked_msg"]
              end
            end

            # Show exit descriptions if any
            if exit_descriptions.any?
              exit_descriptions.each { |desc| lines << desc }
              lines << ""
            end

            lines << "Exits: #{visible_exits.keys.map { |k| k.to_s.upcase }.join(', ')}"
          end

          lines.join("\n")
        end
    end
  end
end
