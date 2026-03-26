# frozen_string_literal: true

module ClassicGame
  module Handlers
    class InteractHandler < BaseHandler
      def handle(command)
        case command[:verb]
        when :talk
          handle_talk(command)
        when :give
          handle_give(command[:target], command[:modifier])
        when :attack
          handle_attack(command[:target])
        else
          failure("I don't understand that command.")
        end
      end

      private

        def handle_talk(command)
          target = command[:target]
          modifier = command[:modifier]

          # "talk to X" parses as target="" modifier="X"
          # "talk to X about Y" parses as target="" modifier="X about Y"
          npc_name, topic_name = resolve_talk_target(target, modifier)

          return failure("Talk to whom?") if npc_name.blank?

          npc_id, npc_def = find_npc(npc_name)
          return failure("You don't see anyone like that here.") unless npc_def
          return failure("You don't see anyone like that here.") unless npc_in_room?(npc_id)

          dialogue = npc_def["dialogue"]
          return failure("#{npc_def['name']} doesn't seem interested in talking.") unless dialogue

          if topic_name.present?
            handle_talk_topic(npc_def, dialogue, topic_name)
          else
            handle_talk_greeting(npc_def, dialogue)
          end
        end

        def resolve_talk_target(target, modifier)
          if target.present?
            [target, modifier]
          elsif modifier.present?
            parts = modifier.split(" about ", 2)
            [parts[0], parts[1]]
          else
            [nil, nil]
          end
        end

        def handle_talk_greeting(npc_def, dialogue)
          response = dialogue["greeting"] || dialogue["default"] || "#{npc_def['name']} nods at you."

          # Set flag if specified on greeting
          game.set_flag(dialogue["sets_flag"], true) if dialogue["sets_flag"]

          success("#{npc_def['name']} says: \"#{response}\"")
        end

        def handle_talk_topic(npc_def, dialogue, topic_name)
          topics = dialogue["topics"]
          return handle_no_topic_match(npc_def, dialogue) unless topics

          topic_id, topic = find_topic_by_keyword(topics, topic_name)
          return handle_no_topic_match(npc_def, dialogue) unless topic

          # Check leads_to locking
          if topic_locked_by_leads_to?(topic_id, topics)
            locked_response = topic["locked_text"] || dialogue["default"] || "I wouldn't know anything about that."
            return success("#{npc_def['name']} says: \"#{locked_response}\"")
          end

          # Check flag requirement
          if topic["requires_flag"] && !game.get_flag(topic["requires_flag"])
            locked_response = topic["locked_text"] || dialogue["default"] || "I wouldn't know anything about that."
            return success("#{npc_def['name']} says: \"#{locked_response}\"")
          end

          # Check item requirement
          if topic["requires_item"] && !item?(topic["requires_item"])
            locked_response = topic["locked_text"] || dialogue["default"] || "I wouldn't know anything about that."
            return success("#{npc_def['name']} says: \"#{locked_response}\"")
          end

          # Set flag if specified
          game.set_flag(topic["sets_flag"], true) if topic["sets_flag"]

          # Unlock subtopics via leads_to
          if topic["leads_to"]
            Array(topic["leads_to"]).each do |subtopic_id|
              game.set_flag("dialogue_unlocked_#{subtopic_id}", true)
            end
          end

          # Build response
          response = "#{npc_def['name']} says: \"#{topic['text']}\""

          # Append leads_to hint
          if topic["leads_to"]
            subtopic_names = Array(topic["leads_to"]).join(", ")
            response += "\n\nYou could ask about: #{subtopic_names}."
          end

          success(response)
        end

        def find_topic_by_keyword(topics, input)
          input_words = input.downcase.split(/\s+/)

          # Try keyword match
          topics.each do |topic_id, topic_def|
            keywords = topic_def["keywords"] || []
            return [topic_id, topic_def] if input_words.any? { |word| keywords.any? { |kw| kw.downcase == word } }
          end

          # Fall back to exact topic key match
          topic_def = topics[input.downcase]
          return [input.downcase, topic_def] if topic_def

          [nil, nil]
        end

        def topic_locked_by_leads_to?(topic_id, topics)
          topics.each_value do |other_topic|
            leads_to = other_topic["leads_to"] || []
            next unless Array(leads_to).include?(topic_id)

            return true unless game.get_flag("dialogue_unlocked_#{topic_id}")
          end
          false
        end

        def handle_no_topic_match(npc_def, dialogue)
          if dialogue["default"]
            success("#{npc_def['name']} says: \"#{dialogue['default']}\"")
          else
            failure("#{npc_def['name']} doesn't know about that.")
          end
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
