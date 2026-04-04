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
          if target.blank?
            # Look at current room
            describe_current_room
          else
            # Look at specific thing
            handle_examine(target)
          end
        end

        def handle_examine(target)
          return failure("Examine what?") unless target

          # Try to find in room items or open containers
          item_id, item_def = find_item(target)
          if item_def && item_accessible?(item_id)
            # Check if examining reveals an exit
            if item_def["on_examine"]&.dig("reveals_exit")
              description = item_def["description"] || "You see nothing special about the #{item_def['name']}."
              return handle_examine_reveals_exit(item_def, description)
            end

            # Check if it's a container
            return handle_examine_container(item_id, item_def) if item_def["is_container"]

            # Regular item examination
            description = item_def["description"] || "You see nothing special about the #{item_def['name']}."
            return success(description)
          end

          # Try to find NPC
          npc_id, npc_def = find_npc(target)
          return success(npc_def["description"] || "You see #{npc_def['name']}.") if npc_def && npc_in_room?(npc_id)

          # Try to find creature
          creature_id, creature_def = find_creature(target)
          if creature_def && creature_in_room?(creature_id)
            description = creature_def["description"] || "You see #{creature_def['name']}."

            # Show health if in combat with this creature
            if in_combat_with?(creature_id)
              combat = player_state["combat"]
              health_pct = (combat["creature_health"].to_f / combat["creature_max_health"] * 100).round
              description += "\n\nThe creature appears to be at #{health_pct}% health."
            end

            return success(description)
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
          return success(base_description) if game.exit_revealed?(player_state["current_room"], direction)

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

        def handle_examine_container(container_id, container_def)
          is_open = game.container_open?(container_id)

          # Get appropriate description based on state
          state_key = is_open ? "open_description" : "closed_description"
          state_label = is_open ? "open" : "closed"
          description = container_def[state_key] ||
                        container_def["description"] ||
                        "The #{container_def['name']} is #{state_label}."

          # If open, list contents
          if is_open
            contents = game.container_contents(container_id)
            if contents.any?
              content_names = contents.map { |item_id| world_snapshot.dig("items", item_id, "name") || item_id }
              description += "\n\nInside you see: #{content_names.join(', ')}"
            elsif container_def["empty_message"]
              description += "\n\n#{container_def['empty_message']}"
            else
              description += "\n\nIt's empty."
            end
          end

          success(description)
        end

        def item_accessible?(item_id)
          item_in_room?(item_id) || item?(item_id) || item_in_open_container?(item_id)
        end

        def item_in_open_container?(item_id)
          # Check all items in room and inventory for containers
          accessible_items = (current_room_state["items"] || []) + (player_state["inventory"] || [])

          accessible_items.each do |potential_container_id|
            container_def = world_snapshot.dig("items", potential_container_id)
            next unless container_def&.dig("is_container")
            next unless game.container_open?(potential_container_id)

            contents = game.container_contents(potential_container_id)
            return true if contents.include?(item_id)

            # Recursively check nested containers
            contents.each do |nested_item_id|
              nested_def = world_snapshot.dig("items", nested_item_id)
              if nested_def&.dig("is_container") && game.container_open?(nested_item_id)
                nested_contents = game.container_contents(nested_item_id)
                return true if nested_contents.include?(item_id)
              end
            end
          end

          false
        end

        def handle_inventory
          inventory = player_state["inventory"] || []

          return success("You are carrying nothing.") if inventory.empty?

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

          # List creatures
          creatures = current_room_state["creatures"] || []
          if creatures.any?
            lines << ""
            creature_names = creatures.map do |creature_id|
              world_snapshot.dig("creatures", creature_id, "name") || creature_id
            end
            lines << "Creatures: #{creature_names.join(', ')}"
          end

          # List other players present in the room
          other_player_ids = game.players_in_room(player_state["current_room"]).reject { |uid| uid == user_id.to_s }
          if other_player_ids.any?
            player_names_map = game.game_state["player_names"] || {}
            other_names = other_player_ids.map { |uid| player_names_map[uid] || "Player #{uid}" }
            lines << ""
            lines << "Also here: #{other_names.join(', ')}"
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

          success(lines.join("\n"))
        end
    end
  end
end
