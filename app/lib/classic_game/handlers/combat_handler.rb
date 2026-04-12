# frozen_string_literal: true

module ClassicGame
  module Handlers
    class CombatHandler < BaseHandler
      def handle(command)
        return failure("You're not in combat!") unless in_combat?

        case command[:verb]
        when :attack
          handle_attack_in_combat
        when :defend
          handle_defend
        when :flee
          handle_flee
        when :use
          handle_use_item(command[:target])
        when :inventory, :examine, :look
          delegate_to_original_handler(command)
        else
          failure("In combat, you can: ATTACK, DEFEND, FLEE, USE [item], or EXAMINE/INVENTORY/LOOK")
        end
      end

      private

        def creature_def
          @creature_def ||= world_snapshot.dig("creatures", game.combat_state["creature_id"])
        end

        def handle_attack_in_combat
          return failure("The creature has vanished!") unless creature_def

          # Clear any defending stance from this player's previous turn
          reset_defending

          player_damage = calculate_player_damage(creature_def)
          new_health = [(game.combat_state["creature_health"] || 0) - player_damage, 0].max
          game.update_creature_health(new_health)

          lines = ["You strike the #{creature_def['name']} for #{player_damage} damage!"]

          return handle_creature_defeat(lines) if new_health <= 0

          lines << "The #{creature_def['name']} has #{new_health} HP remaining."
          success(lines.join("\n"), state_changes: { combat_turn_consumed: true })
        end

        def handle_defend
          return failure("The creature has vanished!") unless creature_def

          new_ps = player_state.dup
          new_ps["combat"] = (new_ps["combat"] || {}).merge("defending" => true)
          update_player_state(new_ps)

          success("You raise your guard, ready to block the next blow.",
                  state_changes: { combat_turn_consumed: true })
        end

        def handle_flee
          return failure("The creature has vanished!") unless creature_def

          reset_defending

          if rand(1..100) > 50
            return success("You try to flee but can't break away from the fight!",
                           state_changes: { combat_turn_consumed: true })
          end

          # Successfully fled — leave combat for this player.
          new_ps = player_state.dup
          new_ps["combat"] = nil
          update_player_state(new_ps)

          ClassicGame::TurnManager.remove_from_combat(game, user_id)

          if game.in_combat?
            # Others are still fighting — this player goes into limbo.
            limbo_ps = player_state.dup
            limbo_ps["waiting_for_combat_end"] = true
            update_player_state(limbo_ps)
            success("You break away from the fight and take cover, waiting for the battle to end.",
                    state_changes: { combat_turn_consumed: true })
          else
            flee_msg = creature_def["on_flee_msg"] || "The #{creature_def['name']} watches you retreat."
            success("You flee from combat!\n#{flee_msg}",
                    state_changes: { combat_ended: true })
          end
        end

        def handle_use_item(item_target)
          return failure("Use what?") unless item_target

          item_id, item_def = find_item(item_target)
          return failure("You don't have that item.") unless item_def
          return failure("You don't have that item.") unless item?(item_id)

          combat_effect = item_def["combat_effect"]
          return failure("You can't use that in combat.") unless combat_effect

          return failure("The creature has vanished!") unless creature_def

          reset_defending

          case combat_effect["type"]
          when "heal"
            heal_amount = combat_effect["amount"] || 10
            current_health = player_state["health"] || 10
            max_health = player_state["max_health"] || 10
            new_health = [current_health + heal_amount, max_health].min
            actual_heal = new_health - current_health

            new_ps = player_state.dup
            new_ps["health"] = new_health
            new_ps["inventory"] = (new_ps["inventory"] || []) - [item_id] if item_def.fetch("consumable", true)
            update_player_state(new_ps)

            success("You use the #{item_def['name']}!\nYou recover #{actual_heal} health.",
                    state_changes: { combat_turn_consumed: true })
          else
            failure("You can't use that in combat.")
          end
        end

        def calculate_player_damage(creature_def)
          base_attack = 5
          weapon_damage = get_weapon_damage(player_state["inventory"] || [])
          randomness = rand(-2..2)
          creature_defense = creature_def["defense"] || 0

          total_attack = base_attack + weapon_damage + randomness
          damage = total_attack - creature_defense
          [damage, 1].max
        end

        def reset_defending
          return unless player_state.dig("combat", "defending")

          new_ps = player_state.dup
          new_ps["combat"] = new_ps["combat"].merge("defending" => false)
          update_player_state(new_ps)
        end

        def handle_creature_defeat(opening_lines = [])
          lines = Array(opening_lines).dup
          defeat_msg = creature_def["on_defeat_msg"] || "The #{creature_def['name']} collapses!"
          lines << defeat_msg

          loot = creature_def["loot"] || []
          if loot.any?
            new_room_state = current_room_state.dup
            new_room_state["items"] ||= []
            new_room_state["items"] += loot
            new_room_state["modified"] = true
            update_room_state(player_state["current_room"], new_room_state)

            loot_names = loot.map { |id| world_snapshot.dig("items", id, "name") || id }
            lines << "The creature drops: #{loot_names.join(', ')}"
          end

          room_id = player_state["current_room"]
          new_room_state = current_room_state.dup
          new_room_state["creatures"] = (new_room_state["creatures"] || []) - [game.combat_state["creature_id"]]
          new_room_state["modified"] = true
          update_room_state(room_id, new_room_state)

          if creature_def["sets_flag_on_defeat"]
            flag_name = creature_def["sets_flag_on_defeat"]
            game.set_flag(flag_name, true)

            room_def = world_snapshot.dig("rooms", room_id)
            (room_def["exits"] || {}).each do |direction, exit_data|
              next unless exit_data.is_a?(Hash) && exit_data["hidden"]
              next if game.exit_revealed?(room_id, direction.to_s)
              next unless exit_data["requires_flag"] == flag_name

              game.reveal_exit(room_id, direction.to_s)
              lines << "" << (exit_data["reveal_msg"] || "A new passage has been revealed to the #{direction}.")
            end
          end

          ClassicGame::TurnManager.exit_combat_mode(game)
          success(lines.join("\n"), state_changes: { combat_ended: true })
        end
    end
  end
end
