# frozen_string_literal: true

module ClassicGame
  module Handlers
    class CombatHandler < BaseHandler
      def handle(command)
        # Verify player is actually in combat
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
          # Allow these commands during combat, delegate to appropriate handlers
          delegate_to_original_handler(command)
        else
          failure("In combat, you can: ATTACK, DEFEND, FLEE, USE [item], or EXAMINE/INVENTORY/LOOK")
        end
      end

      private

        def handle_attack_in_combat
          combat = player_state["combat"]
          creature_id = combat["creature_id"]
          creature_def = world_snapshot.dig("creatures", creature_id)

          return failure("The creature has vanished!") unless creature_def

          # Calculate player damage
          player_damage = calculate_player_damage(creature_def)

          # Apply damage to creature
          combat["creature_health"] -= player_damage
          combat["creature_health"] = [combat["creature_health"], 0].max

          lines = []
          lines << "You strike the #{creature_def['name']} for #{player_damage} damage!"

          # Check if creature is defeated
          return handle_creature_defeat(creature_id, creature_def) if combat["creature_health"] <= 0

          # Creature counterattacks
          creature_damage = calculate_creature_damage(creature_def, defending: false)

          # Apply damage to player
          current_health = player_state["health"] || 10
          current_health -= creature_damage
          current_health = [current_health, 0].max

          new_player_state = player_state.dup
          new_player_state["health"] = current_health
          new_player_state["combat"] = combat
          new_player_state["combat"]["defending"] = false
          new_player_state["combat"]["round_number"] += 1
          update_player_state(new_player_state)

          lines << ""
          lines << "The #{creature_def['name']} retaliates for #{creature_damage} damage!"
          lines << "Your health: #{current_health}/#{player_state['max_health'] || 10}"

          # Check if player died
          return handle_player_death(creature_def) if current_health <= 0

          lines << ""
          lines << "What do you do? (ATTACK, DEFEND, FLEE, USE [item])"

          success(lines.join("\n"))
        end

        def handle_defend
          combat = player_state["combat"]
          creature_id = combat["creature_id"]
          creature_def = world_snapshot.dig("creatures", creature_id)

          return failure("The creature has vanished!") unless creature_def

          # Set defending flag
          combat["defending"] = true

          lines = []
          lines << "You raise your guard!"

          # Creature attacks
          creature_damage = calculate_creature_damage(creature_def, defending: true)

          # Apply damage to player
          current_health = player_state["health"] || 10
          current_health -= creature_damage
          current_health = [current_health, 0].max

          new_player_state = player_state.dup
          new_player_state["health"] = current_health
          new_player_state["combat"] = combat
          new_player_state["combat"]["defending"] = false # Reset for next turn
          new_player_state["combat"]["round_number"] += 1
          update_player_state(new_player_state)

          lines << ""
          lines << "The #{creature_def['name']} attacks but you block most of the damage!"
          max_hp = player_state["max_health"] || 10
          lines << "You take #{creature_damage} damage. Your health: #{current_health}/#{max_hp}"

          # Check if player died
          return handle_player_death(creature_def) if current_health <= 0

          lines << ""
          lines << "What do you do? (ATTACK, DEFEND, FLEE, USE [item])"

          success(lines.join("\n"))
        end

        def handle_flee
          combat = player_state["combat"]
          creature_id = combat["creature_id"]
          creature_def = world_snapshot.dig("creatures", creature_id)

          return failure("The creature has vanished!") unless creature_def

          # 50% chance to flee
          if rand(1..100) > 50
            # Failed to flee - creature gets free attack
            creature_damage = calculate_creature_damage(creature_def, defending: false)

            current_health = player_state["health"] || 10
            current_health -= creature_damage
            current_health = [current_health, 0].max

            new_player_state = player_state.dup
            new_player_state["health"] = current_health
            new_player_state["combat"]["defending"] = false
            new_player_state["combat"]["round_number"] += 1
            update_player_state(new_player_state)

            lines = []
            lines << "You try to flee but the #{creature_def['name']} blocks your escape!"
            lines << "The creature attacks you for #{creature_damage} damage!"
            lines << "Your health: #{current_health}/#{player_state['max_health'] || 10}"

            # Check if player died
            return handle_player_death(creature_def) if current_health <= 0

            lines << ""
            lines << "What do you do? (ATTACK, DEFEND, FLEE, USE [item])"

            return success(lines.join("\n"))
          end

          # Successfully fled
          new_player_state = player_state.dup
          new_player_state["combat"] = nil
          update_player_state(new_player_state)

          lines = []
          lines << "You flee from combat!"
          flee_msg = creature_def["on_flee_msg"] || "The #{creature_def['name']} watches you retreat."
          lines << flee_msg

          success(lines.join("\n"))
        end

        def handle_use_item(item_target)
          return failure(ClassicGame::FunnyResponses.use_what) unless item_target

          # Find the item in inventory
          item_id, item_def = find_item(item_target)
          return failure("You don't have that item.") unless item_def
          return failure("You don't have that item.") unless item?(item_id)

          # Check if item has combat effect
          combat_effect = item_def["combat_effect"]
          return failure("You can't use that in combat.") unless combat_effect

          combat = player_state["combat"]
          creature_id = combat["creature_id"]
          creature_def = world_snapshot.dig("creatures", creature_id)

          return failure("The creature has vanished!") unless creature_def

          lines = []

          case combat_effect["type"]
          when "heal"
            heal_amount = combat_effect["amount"] || 10
            current_health = player_state["health"] || 10
            max_health = player_state["max_health"] || 10

            new_health = [current_health + heal_amount, max_health].min
            actual_heal = new_health - current_health

            lines << "You use the #{item_def['name']}!"
            lines << "You recover #{actual_heal} health!"

            # Remove item if consumable
            new_player_state = player_state.dup
            new_player_state["health"] = new_health

            if item_def.fetch("consumable", true)
              new_player_state["inventory"] = (new_player_state["inventory"] || []) - [item_id]
            end

            # Creature counterattacks
            creature_damage = calculate_creature_damage(creature_def, defending: false)
            new_health -= creature_damage
            new_health = [new_health, 0].max
            new_player_state["health"] = new_health

            new_player_state["combat"]["defending"] = false
            new_player_state["combat"]["round_number"] += 1
            update_player_state(new_player_state)

            lines << ""
            lines << "The #{creature_def['name']} attacks for #{creature_damage} damage!"
            lines << "Your health: #{new_health}/#{max_health}"

            # Check if player died
            return handle_player_death(creature_def) if new_health <= 0

            lines << ""
            lines << "What do you do? (ATTACK, DEFEND, FLEE, USE [item])"

          else
            return failure("You can't use that in combat.")
          end

          success(lines.join("\n"))
        end

        def calculate_player_damage(creature_def)
          base_attack = 5
          weapon_damage = get_weapon_damage(player_state["inventory"] || [])
          randomness = rand(-2..2)
          creature_defense = creature_def["defense"] || 0

          total_attack = base_attack + weapon_damage + randomness
          damage = total_attack - creature_defense

          # Minimum 1 damage
          [damage, 1].max
        end

        def calculate_creature_damage(creature_def, defending:)
          creature_attack = creature_def["attack"] || 5
          randomness = rand(-2..2)
          player_defense = get_defense_bonus(player_state["inventory"] || [])

          # Add +3 defense bonus if defending
          player_defense += 3 if defending

          total_attack = creature_attack + randomness
          damage = total_attack - player_defense

          # Minimum 1 damage
          [damage, 1].max
        end

        def handle_creature_defeat(creature_id, creature_def)
          lines = []
          defeat_msg = creature_def["on_defeat_msg"] || "The #{creature_def['name']} collapses!"
          lines << defeat_msg

          # Handle loot
          loot = creature_def["loot"] || []
          if loot.any?
            # Add loot to room
            new_room_state = current_room_state.dup
            new_room_state["items"] ||= []
            new_room_state["items"] += loot
            new_room_state["modified"] = true
            update_room_state(player_state["current_room"], new_room_state)

            loot_names = loot.map do |item_id|
              world_snapshot.dig("items", item_id, "name") || item_id
            end
            lines << "The creature drops: #{loot_names.join(', ')}"
          end

          # Remove creature from room
          new_room_state = current_room_state.dup
          new_room_state["creatures"] = (new_room_state["creatures"] || []) - [creature_id]
          new_room_state["modified"] = true
          update_room_state(player_state["current_room"], new_room_state)

          # Clear combat state
          new_player_state = player_state.dup
          new_player_state["combat"] = nil
          update_player_state(new_player_state)

          # Set defeat flag if specified
          if creature_def["sets_flag_on_defeat"]
            flag_name = creature_def["sets_flag_on_defeat"]
            game.set_flag(flag_name, true)

            # Auto-reveal any hidden exits now unlocked by this flag
            room_id = player_state["current_room"]
            room_def = world_snapshot.dig("rooms", room_id)
            (room_def["exits"] || {}).each do |direction, exit_data|
              next unless exit_data.is_a?(Hash) && exit_data["hidden"]
              next if game.exit_revealed?(room_id, direction.to_s)
              next unless exit_data["requires_flag"] == flag_name

              game.reveal_exit(room_id, direction.to_s)
              lines << "" << (exit_data["reveal_msg"] || "A new passage has been revealed to the #{direction}.")
            end
          end

          success(lines.join("\n"))
        end

        def handle_player_death(creature_def)
          # Clear combat state
          new_player_state = player_state.dup
          new_player_state["combat"] = nil
          new_player_state["pending_restart"] = true
          update_player_state(new_player_state)

          lines = []
          lines << ""
          lines << "=== GAME OVER ==="
          lines << "You have been defeated by the #{creature_def['name']}!"
          lines << ""
          lines << "Type RESTART to try again."

          failure(lines.join("\n"))
        end

        def delegate_to_original_handler(command)
          # For non-combat commands that should work during combat
          case command[:verb]
          when :inventory, :examine, :look
            ClassicGame::Handlers::ExamineHandler.new(game: game, user_id: user_id).handle(command)
          else
            failure("You can't do that during combat!")
          end
        end
    end
  end
end
