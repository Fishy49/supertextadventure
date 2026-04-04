# frozen_string_literal: true

module ClassicGame
  class MovementProcessor
    class << self
      def process(game:, user_id:)
        messages = []
        player_room = game.player_state(user_id)["current_room"]
        world = game.world_snapshot

        (world["npcs"] || {}).each do |npc_id, npc_def|
          next unless npc_def.is_a?(Hash) && npc_def["movement"]

          msg = process_entity(game: game, entity_type: "npc", entity_id: npc_id,
                               entity_def: npc_def, player_room: player_room)
          messages << msg if msg
        end

        (world["creatures"] || {}).each do |creature_id, creature_def|
          next unless creature_def.is_a?(Hash) && creature_def["movement"]

          msg = process_entity(game: game, entity_type: "creature", entity_id: creature_id,
                               entity_def: creature_def, player_room: player_room)
          messages << msg if msg
        end

        messages
      end

      private

        def process_entity(game:, entity_type:, entity_id:, entity_def:, player_room:)
          movement = entity_def["movement"]

          case movement["type"]
          when "patrol"
            process_patrol(game: game, entity_type: entity_type, entity_id: entity_id,
                           entity_def: entity_def, movement: movement, player_room: player_room)
          when "triggered"
            process_triggered(game: game, entity_type: entity_type, entity_id: entity_id,
                              entity_def: entity_def, movement: movement, player_room: player_room)
          end
        end

        def process_patrol(game:, entity_type:, entity_id:, entity_def:, movement:, player_room:)
          # Skip if entity no longer exists in any room (e.g. defeated creature)
          current_entity_room = find_entity_room(game, entity_type, entity_id)
          return nil unless current_entity_room

          state = game.movement_state(entity_type, entity_id)
          route = movement["route"]
          return nil if route.blank?

          step = state["step"] || 0
          counter = state["move_counter"] || 0
          current_stop = route[step % route.length]
          current_room = current_stop["room"]
          stay_duration = current_stop["stay"] || 1

          counter += 1

          if counter >= stay_duration
            unless_rooms = movement["unless_player_in"] || []
            if unless_rooms.include?(player_room) && current_room == player_room
              game.update_movement_state(entity_type, entity_id,
                                         { "step" => step, "move_counter" => counter })
              return nil
            end

            next_step = (step + 1) % route.length
            next_stop = route[next_step]
            destination = next_stop["room"]

            message = move_entity(game: game, entity_type: entity_type, entity_id: entity_id,
                                  entity_def: entity_def, from_room: current_room,
                                  to_room: destination, player_room: player_room, movement: movement)

            game.update_movement_state(entity_type, entity_id,
                                       { "step" => next_step, "move_counter" => 0 })
            return message
          end

          game.update_movement_state(entity_type, entity_id,
                                     { "step" => step, "move_counter" => counter })
          nil
        end

        def process_triggered(game:, entity_type:, entity_id:, entity_def:, movement:, player_room:)
          state = game.movement_state(entity_type, entity_id)
          return nil if state["triggered"]

          flag = movement["trigger_flag"]
          return nil unless flag && game.get_flag(flag)

          destination = movement["destination"]
          current_room = find_entity_room(game, entity_type, entity_id)
          return nil unless current_room
          return nil if current_room == destination

          message = move_entity(game: game, entity_type: entity_type, entity_id: entity_id,
                                entity_def: entity_def, from_room: current_room,
                                to_room: destination, player_room: player_room, movement: movement)

          game.update_movement_state(entity_type, entity_id, { "triggered" => true })
          message
        end

        def find_entity_room(game, entity_type, entity_id)
          collection_key = entity_type == "npc" ? "npcs" : "creatures"
          rooms = game.world_snapshot["rooms"] || {}

          rooms.each_key do |room_id|
            room_state = game.room_state(room_id)
            return room_id if (room_state[collection_key] || []).include?(entity_id)
          end

          nil
        end

        def move_entity(game:, entity_type:, entity_id:, entity_def:, from_room:, to_room:, player_room:, movement:)
          collection_key = entity_type == "npc" ? "npcs" : "creatures"
          entity_name = entity_def["name"] || entity_id

          old_room_state = game.room_state(from_room).dup
          old_room_state[collection_key] = (old_room_state[collection_key] || []) - [entity_id]
          old_room_state["modified"] = true
          game.update_room_state(from_room, old_room_state)

          new_room_state = game.room_state(to_room).dup
          new_room_state[collection_key] ||= []
          new_room_state[collection_key] << entity_id
          new_room_state["modified"] = true
          game.update_room_state(to_room, new_room_state)

          if from_room == player_room
            movement["depart_text"] || "#{entity_name} leaves."
          elsif to_room == player_room
            movement["arrive_text"] || "#{entity_name} arrives."
          end
        end
    end
  end
end
