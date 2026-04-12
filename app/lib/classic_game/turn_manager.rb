# frozen_string_literal: true

module ClassicGame
  class TurnManager
    class << self
      # Returns true if the given user is allowed to act this turn.
      # During combat: follows combat_turn_order. Otherwise: normal turn_order.
      # Single-player games always return true.
      def can_act?(game, user_id)
        ps = game.player_state(user_id)

        # Fled players are in limbo until combat ends.
        return false if ps["waiting_for_combat_end"]

        # During combat, only the current combatant may act.
        return game.current_combat_user_id == user_id.to_i if game.in_combat?

        order = game.turn_state["turn_order"] || []
        return true if order.length <= 1

        # Player with a pending roll may always act to resolve it
        return true if ps["pending_roll"].present?

        game.current_turn_user_id == user_id.to_i
      end

      # Advance to the next player's turn. No-op in single-player games.
      def advance(game)
        return if (game.turn_state["turn_order"] || []).length <= 1

        game.advance_turn
      end

      # Initialize combat: shared creature HP, per-player combat flags, and a
      # roll-based combat_turn_order. starting_combatant controls who goes
      # first — an Integer user_id to prioritize a player, :creature to force
      # the creature (for aggro), or nil to use pure initiative order.
      def enter_combat_mode(game, room_id, creature_id, starting_combatant: nil)
        creature_def = game.world_snapshot.dig("creatures", creature_id) || {}
        creature_health = creature_def["health"] || 10

        game.set_combat_state(
          room_id: room_id,
          creature_id: creature_id,
          creature_health: creature_health
        )

        players = game.players_in_room(room_id).keys

        players.each do |uid|
          ps = game.player_state(uid).dup
          ps["combat"] = { "active" => true, "defending" => false }
          game.update_player_state(uid, ps)
        end

        combatants = players.map do |uid|
          { "id" => uid.to_s, "type" => "player", "initiative" => rand(1..20) }
        end
        combatants << {
          "id" => creature_id.to_s, "type" => "creature", "initiative" => rand(1..20)
        }
        combatants.sort_by! { |c| [-c["initiative"], c["type"] == "creature" ? 1 : 0] }

        ts = game.turn_state.dup
        ts["combat_turn_order"] = combatants
        ts["combat_current_index"] = resolve_starting_index(combatants, starting_combatant)

        game.game_state["turn_state"] = ts
        game.save!
      end

      # Tear down combat: clear the shared creature state, combat turn order,
      # per-player combat flags, and any combat-limbo flags.
      def exit_combat_mode(game)
        game.clear_combat_state if game.in_combat?

        ts = game.turn_state.dup
        ts.delete("combat_turn_order")
        ts.delete("combat_current_index")
        game.game_state["turn_state"] = ts

        (game.game_state["player_states"] || {}).each_value do |state|
          state.delete("combat")
          state.delete("waiting_for_combat_end")
        end

        game.save!
      end

      # Remove a specific player from the combat turn order (flee or death).
      # If no player combatants remain, ends combat entirely.
      def remove_from_combat(game, user_id)
        ts = game.turn_state.dup
        order = ts["combat_turn_order"] || []
        removed_index = order.index { |c| c["id"] == user_id.to_s && c["type"] == "player" }
        new_order = order.reject { |c| c["id"] == user_id.to_s && c["type"] == "player" }
        ts["combat_turn_order"] = new_order

        # If we removed an entry at or before the current index, shift the
        # index down so the "current" combatant doesn't skip forward.
        if removed_index && new_order.any?
          current = ts["combat_current_index"] || 0
          current -= 1 if removed_index < current
          ts["combat_current_index"] = current % new_order.length
        end

        game.game_state["turn_state"] = ts
        game.save!

        # If no player combatants remain, end combat entirely.
        any_players = new_order.any? { |c| c["type"] == "player" }
        exit_combat_mode(game) unless any_players
      end

      # Returns a context-sensitive "not your turn" message.
      def waiting_message(game, user_id)
        ps = game.player_state(user_id)
        return "Waiting for combat to finish..." if ps["waiting_for_combat_end"]

        if game.in_combat?
          combatant = game.current_combatant
          if combatant && combatant["type"] == "creature"
            creature_name = game.world_snapshot.dig("creatures", combatant["id"], "name") || combatant["id"]
            return "The #{creature_name} is taking its turn..."
          elsif combatant
            name = game.character_name_for(combatant["id"].to_i) || "another player"
            return "Waiting for #{name}'s combat turn..."
          end
        end

        ts = game.turn_state
        order = ts["turn_order"] || []
        current_id = order[ts["current_index"] || 0]
        name = game.character_name_for(current_id) || "another player"
        "It's not your turn. Waiting for #{name}..."
      end

      private

        def resolve_starting_index(combatants, starting_combatant)
          case starting_combatant
          when :creature
            combatants.index { |c| c["type"] == "creature" } || 0
          when Integer
            idx = combatants.index { |c| c["type"] == "player" && c["id"] == starting_combatant.to_s }
            idx || 0
          else
            0
          end
        end
    end
  end
end
