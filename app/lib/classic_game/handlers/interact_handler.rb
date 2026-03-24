# frozen_string_literal: true

module ClassicGame
  module Handlers
    class InteractHandler < BaseHandler
      def handle(command)
        case command[:verb]
        when :talk
          handle_talk(command[:target], command[:modifier])
        when :give
          handle_give(command[:target], command[:modifier])
        when :attack
          handle_attack(command[:target])
        else
          failure("I don't understand that command.")
        end
      end

      private

        def handle_talk(target, modifier)
          # modifier holds "npc_name" or "npc_name about topic_words"
          raw = modifier.presence || target.presence
          return failure("Talk to whom?") unless raw

          # split on " about " to separate npc from topic
          parts = raw.split(/\s+about\s+/, 2)
          npc_input   = parts[0].strip
          topic_input = parts[1]&.strip

          npc_id, npc_def = find_npc(npc_input)
          return failure("You don't see anyone like that here.") unless npc_def
          return failure("You don't see anyone like that here.") unless npc_in_room?(npc_id)

          dialogue = npc_def["dialogue"]
          return failure("#{npc_def['name']} doesn't seem interested in talking.") unless dialogue

          return handle_greeting(npc_def) unless topic_input

          handle_topic(npc_id, npc_def, topic_input)
        end

        def handle_greeting(npc_def)
          greeting = npc_def.dig("dialogue", "greeting") ||
                     npc_def.dig("dialogue", "default") ||
                     "#{npc_def['name']} nods at you."
          npc_says(npc_def, greeting)
        end

        def handle_topic(npc_id, npc_def, topic_input)
          dialogue = npc_def["dialogue"]
          topics   = dialogue["topics"] || {}
          words    = topic_input.downcase.split

          matched_id, matched_def = topics.find do |_tid, tdef|
            keywords = (tdef["keywords"] || []).map(&:downcase)
            words.any? { |w| keywords.include?(w) }
          end

          unless matched_def
            default_text = dialogue["default"] || "#{npc_def['name']} shrugs."
            return npc_says(npc_def, default_text)
          end

          unless topic_unlocked?(npc_id, matched_id, matched_def, topics)
            locked = matched_def["locked_text"] || dialogue["default"] || "#{npc_def['name']} shrugs."
            return npc_says(npc_def, locked)
          end

          locked_response = locked_response_for(npc_def, matched_def, dialogue)
          return locked_response if locked_response

          game.set_flag(matched_def["sets_flag"], true) if matched_def["sets_flag"]
          record_leads_to_unlocks(npc_id, matched_def)
          npc_says(npc_def, matched_def["text"])
        end

        def locked_response_for(npc_def, topic_def, dialogue)
          if (req_flag = topic_def["requires_flag"]) && !game.get_flag(req_flag)
            locked = topic_def["locked_text"] || dialogue["default"] || "#{npc_def['name']} shrugs."
            return npc_says(npc_def, locked)
          end

          if (req_item = topic_def["requires_item"]) && !item?(req_item)
            locked = topic_def["locked_text"] || dialogue["default"] || "#{npc_def['name']} shrugs."
            return npc_says(npc_def, locked)
          end

          nil
        end

        def topic_unlocked?(npc_id, topic_id, _topic_def, all_topics)
          gated = all_topics.any? do |_tid, tdef|
            (tdef["leads_to"] || []).include?(topic_id)
          end
          return true unless gated

          unlocked = player_state.dig("dialogue_unlocked", npc_id) || []
          unlocked.include?(topic_id)
        end

        def record_leads_to_unlocks(npc_id, topic_def)
          leads_to = topic_def["leads_to"]
          return unless leads_to&.any?

          new_state = player_state.dup
          new_state["dialogue_unlocked"] = (player_state["dialogue_unlocked"] || {}).dup
          new_state["dialogue_unlocked"][npc_id] ||= []
          new_state["dialogue_unlocked"][npc_id] = (
            new_state["dialogue_unlocked"][npc_id] + leads_to
          ).uniq
          update_player_state(new_state)
        end

        def npc_says(npc_def, text)
          success("#{npc_def['name']} says: \"#{text}\"")
        end

        def handle_give(item_target, npc_target)
          return failure("Give what to whom?") unless item_target && npc_target

          # Find the item
          item_id, item_def = find_item(item_target)
          return failure("You don't have that item.") unless item_def
          return failure("You don't have that item.") unless item?(item_id)

          # Find the NPC
          npc_id, npc_def = find_npc(npc_target)
          return failure("You don't see anyone like that here.") unless npc_def
          return failure("You don't see anyone like that here.") unless npc_in_room?(npc_id)

          # Check if NPC accepts this item
          accepts_item = npc_def["accepts_item"]
          gives_item = npc_def["gives_item"]
          accept_message = npc_def["accept_message"]

          if accepts_item == item_id
            # Remove item from player inventory
            new_player_state = player_state.dup
            new_player_state["inventory"] = (new_player_state["inventory"] || []) - [item_id]

            # Give reward item if specified
            if gives_item
              new_player_state["inventory"] ||= []
              new_player_state["inventory"] << gives_item
            end

            update_player_state(new_player_state)

            # Set quest flag if specified
            game.set_flag(npc_def["sets_flag"], true) if npc_def["sets_flag"]

            message = accept_message || "#{npc_def['name']} accepts the #{item_def['name']}."
            if gives_item
              reward_name = world_snapshot.dig("items", gives_item, "name") || gives_item
              message += " In return, #{npc_def['name']} gives you a #{reward_name}."
            end

            return success(message)
          end

          failure("#{npc_def['name']} doesn't want that.")
        end

        def handle_attack(target)
          return failure("Attack what?") unless target

          # Find creature
          creature_id, creature_def = find_creature(target)
          return failure("You don't see that creature here.") unless creature_def
          return failure("You don't see that creature here.") unless creature_in_room?(creature_id)
          return failure("You're already fighting!") if in_combat?

          # Initialize player health if not set
          new_player_state = player_state.dup
          starting_health = game.starting_hp || 10
          new_player_state["health"] ||= starting_health
          new_player_state["max_health"] ||= starting_health

          # Create combat state
          combat = {
            "active" => true,
            "creature_id" => creature_id,
            "creature_health" => creature_def["health"],
            "creature_max_health" => creature_def["health"],
            "round_number" => 1,
            "defending" => false
          }

          # Roll initiative
          player_roll = rand(1..20)
          creature_roll = rand(1..20)
          combat["turn_order"] = player_roll >= creature_roll ? "player" : "creature"

          # Build response
          lines = []
          lines << "You engage the #{creature_def['name']} in combat!"
          lines << ""

          if combat["turn_order"] == "player"
            # Player goes first
            new_player_state["combat"] = combat
            update_player_state(new_player_state)

            lines << "You strike first! What do you do?"
            lines << "Commands: ATTACK, DEFEND, FLEE, USE [item]"
          else
            # Creature attacks first
            creature_attack = creature_def["attack"] || 5
            randomness = rand(-2..2)
            player_defense = get_defense_bonus(new_player_state["inventory"] || [])

            total_attack = creature_attack + randomness
            damage = total_attack - player_defense
            damage = [damage, 1].max

            # Apply damage
            new_player_state["health"] -= damage
            new_player_state["health"] = [new_player_state["health"], 0].max

            # Check if player died on first hit (unlikely but possible)
            if new_player_state["health"] <= 0
              update_player_state(new_player_state)
              lines << "The #{creature_def['name']} strikes first!"
              lines << "The creature deals #{damage} damage!"
              lines << ""
              lines << "=== GAME OVER ==="
              lines << "You have been defeated by the #{creature_def['name']} before you could react!"
              lines << ""
              lines << "Type RESTART to try again."

              new_player_state["pending_restart"] = true
              update_player_state(new_player_state)
              return failure(lines.join("\n"))
            end

            # Save combat state
            new_player_state["combat"] = combat
            update_player_state(new_player_state)

            lines << "The #{creature_def['name']} strikes first!"
            lines << "The creature deals #{damage} damage!"
            lines << "Your health: #{new_player_state['health']}/#{new_player_state['max_health']}"
            lines << ""
            lines << "What do you do? (ATTACK, DEFEND, FLEE, USE [item])"
          end

          success(lines.join("\n"))
        end
    end
  end
end
