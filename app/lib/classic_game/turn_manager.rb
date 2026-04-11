# frozen_string_literal: true

module ClassicGame
  class TurnManager
    class << self
      # Returns true if the given user is allowed to act this turn.
      # Single-player games always return true.
      def can_act?(game, user_id)
        order = game.turn_state["turn_order"] || []
        return true if order.length <= 1

        # Player with a pending roll may always act to resolve it
        ps = game.player_state(user_id)
        return true if ps["pending_roll"].present?

        game.current_turn_user_id == user_id.to_i
      end

      # Advance to the next player's turn. No-op in single-player games.
      def advance(game)
        return if (game.turn_state["turn_order"] || []).length <= 1

        game.advance_turn
      end

      # Set up a multi-combatant initiative order for the players in the room
      # plus the named creature. Stores result in turn_state["combat_turn_order"].
      def enter_combat_mode(game, room_id, creature_id)
        players = game.players_in_room(room_id).map { |uid, _| uid }

        combatants = players.map { |uid| { "id" => uid.to_s, "type" => "player", "initiative" => rand(1..20) } }
        combatants << { "id" => creature_id.to_s, "type" => "creature", "initiative" => rand(1..20) }

        combatants.sort_by! { |c| [-c["initiative"], c["type"] == "creature" ? 1 : 0] }

        ts = game.turn_state.dup
        ts["combat_turn_order"] = combatants
        ts["combat_current_index"] = 0
        game.game_state["turn_state"] = ts
        game.save!
      end

      # Clear the combat turn order and restore all players to normal turns.
      def exit_combat_mode(game)
        ts = game.turn_state.dup
        ts.delete("combat_turn_order")
        ts.delete("combat_current_index")
        game.game_state["turn_state"] = ts

        (game.game_state["player_states"] || {}).each_value do |state|
          state.delete("waiting_for_combat_end")
        end

        game.save!
      end

      # Remove a specific player from the combat turn order (flee or death).
      def remove_from_combat(game, user_id)
        ts = game.turn_state.dup
        order = ts["combat_turn_order"] || []
        ts["combat_turn_order"] = order.reject { |c| c["id"] == user_id.to_s && c["type"] == "player" }
        game.game_state["turn_state"] = ts
        game.save!
      end

      # Returns a "not your turn" message naming the current player.
      def waiting_message(game, _user_id)
        ts = game.turn_state
        order = ts["turn_order"] || []
        current_id = order[ts["current_index"] || 0]
        name = game.character_name_for(current_id) || "another player"
        "It's not your turn. Waiting for #{name}..."
      end
    end
  end
end
