# frozen_string_literal: true

module ClassicGame
  class NpcMovementProcessor
    class << self
      def process(game:, user_id:)
        game.increment_turn_count

        player_state = game.player_state(user_id)
        player_room = player_state["current_room"]
        combat_creature_id = player_state.dig("combat", "creature_id")

        world = game.world_snapshot
        messages = []

        collect_movable_entities(world).each do |entity|
          entity_id, entity_def, = entity
          next if entity_id == combat_creature_id

          movement = entity_def["movement"]
          entity_messages = case movement["type"]
                            when "patrol"
                              process_patrol(game, entity, player_room, world)
                            when "triggered"
                              process_triggered(game, entity, player_room, world)
                            else
                              []
                            end

          messages.concat(entity_messages)
        end

        messages
      end

      private

        def collect_movable_entities(world)
          entities = []
          %w[npcs creatures].each do |entity_type|
            (world[entity_type] || {}).each do |entity_id, entity_def|
              next unless entity_def.is_a?(Hash) && entity_def["movement"]

              entities << [entity_id, entity_def, entity_type]
            end
          end
          entities
        end

        def process_patrol(game, entity, player_room, world)
          entity_id, entity_def, entity_type = entity
          state = game.npc_movement_state(entity_id)
          state = { "schedule_index" => 0, "turns_in_step" => 0 } if state.empty?

          state["turns_in_step"] += 1

          schedule = entity_def.dig("movement", "schedule")
          current_step = schedule[state["schedule_index"]]

          messages = []

          if state["turns_in_step"] > current_step["duration"]
            next_index = (state["schedule_index"] + 1) % schedule.length
            next_step = schedule[next_index]

            blocked = next_step["blocked_while_player_in"]
            if blocked.is_a?(Array) && blocked.include?(player_room)
              game.update_npc_movement_state(entity_id, state)
              return []
            end

            state["schedule_index"] = next_index
            state["turns_in_step"] = 1

            current_room = find_entity_room(game, entity_id, entity_type, world)
            target_room = next_step["room"]

            if current_room && current_room != target_room
              move_entity(game, entity_id, entity_type, current_room, target_room)
              messages = build_messages(entity_def, current_room, target_room, player_room)
            end
          end

          game.update_npc_movement_state(entity_id, state)
          messages
        end

        def process_triggered(game, entity, player_room, world)
          entity_id, entity_def, entity_type = entity
          movement = entity_def["movement"]
          state = game.npc_movement_state(entity_id)

          return [] if state["triggered"]
          return [] unless game.get_flag(movement["trigger_flag"])

          current_room = find_entity_room(game, entity_id, entity_type, world)

          state["triggered"] = true
          game.update_npc_movement_state(entity_id, state)

          destination = movement["destination"]
          return [] unless current_room && current_room != destination

          move_entity(game, entity_id, entity_type, current_room, destination)
          build_messages(entity_def, current_room, destination, player_room)
        end

        def move_entity(game, entity_id, entity_type, from_room, to_room)
          old_state = game.room_state(from_room).dup
          old_state[entity_type] = (old_state[entity_type] || []).dup
          old_state[entity_type].delete(entity_id)
          game.update_room_state(from_room, old_state)

          new_state = game.room_state(to_room).dup
          new_state[entity_type] = (new_state[entity_type] || []).dup
          new_state[entity_type] << entity_id unless new_state[entity_type].include?(entity_id)
          game.update_room_state(to_room, new_state)
        end

        def find_entity_room(game, entity_id, entity_type, world)
          (world["rooms"] || {}).each_key do |room_id|
            return room_id if game.room_state(room_id)[entity_type]&.include?(entity_id)
          end
          nil
        end

        def build_messages(entity_def, from_room, to_room, player_room)
          messages = []
          movement = entity_def["movement"]
          name = entity_def["name"]

          messages << (movement["depart_msg"] || "The #{name} leaves.") if from_room == player_room
          messages << (movement["arrive_msg"] || "The #{name} arrives.") if to_room == player_room

          messages
        end
    end
  end
end
