# frozen_string_literal: true

module ClassicGame
  module Handlers
    # Handles GIVE <item> TO <player> — transfers an item between two players
    # who are in the same room. Distinct from InteractHandler's NPC give logic.
    class GiveHandler < BaseHandler
      def handle(command)
        item_target = command[:target]
        recipient_name = command[:modifier]

        return failure("Give what to whom?") unless item_target && recipient_name

        item_id, item_def = find_item(item_target)
        return failure("You don't have that item.") unless item_def
        return failure("You don't have that item.") unless item?(item_id)

        recipient_user_id, = find_player(recipient_name)
        return failure("You don't see #{recipient_name} here.") unless recipient_user_id
        return failure("You don't see #{recipient_name} here.") unless player_in_room?(recipient_user_id)

        transfer_item(item_id, recipient_user_id)

        recipient_display = player_display_name(recipient_user_id)
        success("You give the #{item_def['name']} to #{recipient_display}.")
      end

      private

        def transfer_item(item_id, recipient_user_id)
          new_state = player_state.dup
          new_state["inventory"] = (new_state["inventory"] || []) - [item_id]
          update_player_state(new_state)

          recipient_state = game.player_state(recipient_user_id).dup
          recipient_state["inventory"] ||= []
          recipient_state["inventory"] << item_id
          game.update_player_state(recipient_user_id, recipient_state)
        end

        def player_display_name(user_id)
          game.game_state.dig("player_names", user_id.to_s) || "Player #{user_id}"
        end
    end
  end
end
