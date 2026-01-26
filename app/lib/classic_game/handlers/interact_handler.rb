# frozen_string_literal: true

module ClassicGame
  module Handlers
    class InteractHandler < BaseHandler
      def handle(command)
        case command[:verb]
        when :talk
          handle_talk(command[:target])
        when :give
          handle_give(command[:target], command[:modifier])
        when :attack
          handle_attack(command[:target])
        else
          failure("I don't understand that command.")
        end
      end

      private

      def handle_talk(target)
        return failure("Talk to whom?") unless target

        # Find the NPC
        npc_id, npc_def = find_npc(target)
        return failure("You don't see anyone like that here.") unless npc_def
        return failure("You don't see anyone like that here.") unless npc_in_room?(npc_id)

        # Get dialogue
        dialogue = npc_def["dialogue"]
        return failure("#{npc_def['name']} doesn't seem interested in talking.") unless dialogue

        # For now, return default dialogue
        # Future: could implement conversation trees, quest states, etc.
        response = dialogue["default"] || "#{npc_def['name']} nods at you."

        success("#{npc_def['name']} says: \"#{response}\"")
      end

      def handle_give(item_target, npc_target)
        return failure("Give what to whom?") unless item_target && npc_target

        # Find the item
        item_id, item_def = find_item(item_target)
        return failure("You don't have that item.") unless item_def
        return failure("You don't have that item.") unless has_item?(item_id)

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
          if npc_def["sets_flag"]
            game.set_flag(npc_def["sets_flag"], true)
          end

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

        # This is a placeholder for combat system
        # Future: implement creature stats, combat rounds, etc.

        failure("Combat is not yet implemented. Try a different approach!")
      end
    end
  end
end
