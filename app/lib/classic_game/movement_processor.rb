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

          ctx = build_context(game, "npc", npc_id, npc_def, player_room)
          msg = process_entity(ctx)
          messages << msg if msg
        end

        (world["creatures"] || {}).each do |creature_id, creature_def|
          next unless creature_def.is_a?(Hash) && creature_def["movement"]

          ctx = build_context(game, "creature", creature_id, creature_def, player_room)
          msg = process_entity(ctx)
          messages << msg if msg
        end

        messages
      end

      private

        def build_context(game, entity_type, entity_id, entity_def, player_room)
          {
            game: game, entity_type: entity_type, entity_id: entity_id,
            entity_def: entity_def, movement: entity_def["movement"],
            player_room: player_room
          }
        end

        def process_entity(ctx)
          case ctx[:movement]["type"]
          when "patrol"
            process_patrol(ctx)
          when "triggered"
            process_triggered(ctx)
          end
        end

        def process_patrol(ctx)
          game = ctx[:game]
          entity_type = ctx[:entity_type]
          entity_id = ctx[:entity_id]
          movement = ctx[:movement]

          # Skip if entity no longer exists in any room (e.g. defeated creature)
          return nil unless find_entity_room(game, entity_type, entity_id)

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
            if unless_rooms.include?(ctx[:player_room]) && current_room == ctx[:player_room]
              game.update_movement_state(entity_type, entity_id,
                                         { "step" => step, "move_counter" => counter })
              return nil
            end

            next_step = (step + 1) % route.length
            destination = route[next_step]["room"]

            message = move_entity(ctx, from_room: current_room, to_room: destination)

            game.update_movement_state(entity_type, entity_id,
                                       { "step" => next_step, "move_counter" => 0 })
            return message
          end

          game.update_movement_state(entity_type, entity_id,
                                     { "step" => step, "move_counter" => counter })
          nil
        end

        def process_triggered(ctx)
          game = ctx[:game]
          entity_type = ctx[:entity_type]
          entity_id = ctx[:entity_id]
          movement = ctx[:movement]

          state = game.movement_state(entity_type, entity_id)
          return nil if state["triggered"]

          flag = movement["trigger_flag"]
          return nil unless flag && game.get_flag(flag)

          destination = movement["destination"]
          current_room = find_entity_room(game, entity_type, entity_id)
          return nil unless current_room
          return nil if current_room == destination

          message = move_entity(ctx, from_room: current_room, to_room: destination)

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

        def move_entity(ctx, from_room:, to_room:)
          game = ctx[:game]
          entity_type = ctx[:entity_type]
          collection_key = entity_type == "npc" ? "npcs" : "creatures"
          entity_name = ctx[:entity_def]["name"] || ctx[:entity_id]

          old_room_state = game.room_state(from_room).dup
          old_room_state[collection_key] = (old_room_state[collection_key] || []) - [ctx[:entity_id]]
          old_room_state["modified"] = true
          game.update_room_state(from_room, old_room_state)

          new_room_state = game.room_state(to_room).dup
          new_room_state[collection_key] ||= []
          new_room_state[collection_key] << ctx[:entity_id]
          new_room_state["modified"] = true
          game.update_room_state(to_room, new_room_state)

          if from_room == ctx[:player_room]
            ctx[:movement]["depart_text"] || "#{entity_name} leaves."
          elsif to_room == ctx[:player_room]
            ctx[:movement]["arrive_text"] || "#{entity_name} arrives."
          end
        end
    end
  end
end
