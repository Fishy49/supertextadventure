# frozen_string_literal: true

module ClassicGame
  module Handlers
    class ItemHandler < BaseHandler
      def handle(command)
        case command[:verb]
        when :take
          handle_take(command[:target])
        when :drop
          handle_drop(command[:target])
        when :use
          handle_use(command[:target], command[:modifier])
        else
          failure("I don't understand that command.")
        end
      end

      private

      def handle_take(target)
        return failure("Take what?") unless target

        # Find the item
        item_id, item_def = find_item(target)
        return failure("You don't see that here.") unless item_def

        # Check if it's in the room
        return failure("You don't see that here.") unless item_in_room?(item_id)

        # Check if it's takeable
        unless item_def.fetch("takeable", true)
          return failure(item_def["cant_take_msg"] || "You can't take that.")
        end

        # Add to inventory
        new_player_state = player_state.dup
        new_player_state["inventory"] ||= []
        new_player_state["inventory"] << item_id
        update_player_state(new_player_state)

        # Remove from room
        new_room_state = current_room_state.dup
        new_room_state["items"] = (new_room_state["items"] || []) - [item_id]
        new_room_state["modified"] = true
        update_room_state(player_state["current_room"], new_room_state)

        success("You take the #{item_def['name']}.")
      end

      def handle_drop(target)
        return failure("Drop what?") unless target

        # Find the item
        item_id, item_def = find_item(target)
        return failure("You don't have that.") unless item_def

        # Check if player has it
        return failure("You don't have that.") unless has_item?(item_id)

        # Remove from inventory
        new_player_state = player_state.dup
        new_player_state["inventory"] = (new_player_state["inventory"] || []) - [item_id]
        update_player_state(new_player_state)

        # Add to room
        new_room_state = current_room_state.dup
        new_room_state["items"] ||= []
        new_room_state["items"] << item_id
        new_room_state["modified"] = true
        update_room_state(player_state["current_room"], new_room_state)

        success("You drop the #{item_def['name']}.")
      end

      def handle_use(item_target, modifier)
        return failure("Use what?") unless item_target

        # Find the item
        item_id, item_def = find_item(item_target)
        return failure("You don't have that item.") unless item_def
        return failure("You don't have that item.") unless has_item?(item_id)

        # First check if using item on an exit
        if modifier && is_direction?(modifier)
          return handle_use_on_exit(item_id, item_def, modifier)
        end

        # Check if it has a use action
        use_action = item_def["on_use"]

        if use_action.nil?
          return failure("You can't use that here.")
        end

        # Handle different types of use actions
        case use_action["type"]
        when "unlock"
          handle_unlock(item_id, item_def, use_action, modifier)
        when "message"
          success(use_action["text"])
        when "script"
          # For future: custom script execution
          failure("That doesn't do anything right now.")
        else
          failure("You can't use that here.")
        end
      end

      def handle_unlock(item_id, item_def, use_action, modifier)
        required_target = use_action["requires_target"]

        if required_target && modifier.nil?
          return failure("Use the #{item_def['name']} on what?")
        end

        # Set a global flag to indicate door is unlocked
        flag_name = use_action["sets_flag"]
        if flag_name
          game.set_flag(flag_name, true)
          return success(use_action["success_msg"] || "You use the #{item_def['name']}.")
        end

        success(use_action["success_msg"] || "You use the #{item_def['name']}.")
      end

      def is_direction?(word)
        # Common directions
        directions = %w[north south east west up down n s e w ne nw se sw northeast northwest southeast southwest in out]
        directions.include?(word.to_s.downcase)
      end

      def handle_use_on_exit(item_id, item_def, direction)
        # Get the exit data
        exit_data = current_room_def.dig("exits", direction.to_s) || current_room_def.dig("exits", direction.to_sym)

        return failure("You can't go that way.") unless exit_data
        return failure("That won't do anything.") if exit_data.is_a?(String)

        # Check if this exit accepts this item
        use_item = exit_data["use_item"]
        return failure("You can't use that there.") unless use_item == item_id

        # Check if already unlocked
        if exit_data["permanently_unlock"] && game.exit_unlocked?(player_state["current_room"], direction)
          return failure("That won't do anything.")
        end

        # Unlock the exit
        on_unlock_msg = exit_data["on_unlock"] || "You use the #{item_def['name']}."

        # Permanently unlock if specified
        if exit_data["permanently_unlock"]
          game.unlock_exit(player_state["current_room"], direction)
        end

        # Consume item if specified
        if exit_data["consume_item"]
          new_player_state = player_state.dup
          new_player_state["inventory"] = (new_player_state["inventory"] || []) - [item_id]
          update_player_state(new_player_state)
        end

        # Set flag if specified
        if exit_data["sets_flag"]
          game.set_flag(exit_data["sets_flag"], true)
        end

        success(on_unlock_msg)
      end
    end
  end
end
