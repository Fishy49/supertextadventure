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

          # If no NPC found or not in room, try creature
          return handle_talk_to_creature(npc_name) unless npc_def && npc_in_room?(npc_id)

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

        def handle_no_topic_match(npc_def, _dialogue)
          failure("#{npc_def['name']} doesn't know anything about that.")
        end

        def handle_give(item_target, npc_target)
          return failure("Give what to whom?") unless item_target && npc_target

          # Find the item
          item_id, item_def = find_item(item_target)
          return failure("You don't have that item.") unless item_def
          return failure("You don't have that item.") unless item?(item_id)

          # Player characters take priority over NPCs with the same name
          player_uid, player_name = find_player_in_room(npc_target)
          return handle_give_to_player(item_id, item_def, player_uid, player_name) if player_uid

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

        def handle_talk_to_creature(name)
          creature_id, creature_def = find_creature(name)
          return failure("You don't see anyone like that here.") unless creature_def
          return failure("You don't see anyone like that here.") unless creature_in_room?(creature_id)

          talk_text = creature_def["talk_text"] || "It has no clue what you're saying."
          success(talk_text)
        end

        def handle_give_to_player(item_id, item_def, receiver_uid, receiver_name)
          # Remove item from giver's inventory
          new_giver_state = player_state.dup
          new_giver_state["inventory"] = (new_giver_state["inventory"] || []) - [item_id]
          update_player_state(new_giver_state)

          # Add item to receiver's inventory
          receiver_state = game.player_state(receiver_uid).dup
          receiver_state["inventory"] ||= []
          receiver_state["inventory"] << item_id
          game.update_player_state(receiver_uid, receiver_state)

          giver_name = game.character_name_for(user_id) || "Someone"
          bystanders = other_players_in_room.keys - [receiver_uid]
          give_data = {
            receiver_user_id: receiver_uid,
            item_id: item_id,
            receiver_text: "**#{giver_name} gives you the #{item_def['name']}.**"
          }
          if bystanders.any?
            give_data[:bystander_text] = "**#{giver_name} gives the #{item_def['name']} to #{receiver_name}.**"
            give_data[:bystander_audience] = bystanders
          end
          success(
            "You give the #{item_def['name']} to #{receiver_name}.",
            state_changes: { give_to_player: give_data }
          )
        end

        def handle_attack(target)
          return failure("Attack what?") unless target

          creature_id, creature_def = find_creature(target)
          return failure("You don't see that creature here.") unless creature_def
          return failure("You don't see that creature here.") unless creature_in_room?(creature_id)
          return failure("You're already fighting!") if in_combat?

          # Ensure each room player has a baseline health before entering combat.
          starting_health = game.starting_hp || 10
          room_id = player_state["current_room"]
          game.players_in_room(room_id).each_key do |uid|
            ps = game.player_state(uid).dup
            ps["health"] ||= starting_health
            ps["max_health"] ||= starting_health
            game.update_player_state(uid, ps)
          end

          # Initialize shared combat state and combat turn order. The acting
          # player goes first so their ATTACK command is their opening turn.
          ClassicGame::TurnManager.enter_combat_mode(
            game, room_id, creature_id, starting_combatant: user_id.to_i
          )

          opening = "You engage the #{creature_def['name']} in combat!"
          attack_result = ClassicGame::Handlers::CombatHandler
                          .new(game: game, user_id: user_id)
                          .handle({ verb: :attack, target: nil, modifier: nil, raw: "attack" })

          success(
            "#{opening}\n\n#{attack_result[:response]}",
            state_changes: attack_result[:state_changes] || {}
          )
        end
    end
  end
end
