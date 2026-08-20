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
        return true if order.empty?

        # Benched players (registered but pulled from the rotation by the
        # host) may not act, even if only one active player remains.
        return false unless order.include?(user_id.to_i)

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

      # Host override: skip the current turn. During combat this advances the
      # combat order and runs any creature turns until a player is up again;
      # otherwise it advances the normal rotation. Returns a hash with the
      # skipped player's user id (nil if none) and any creature narration.
      def host_skip(game)
        if game.in_combat?
          skipped = game.current_combat_user_id
          { skipped_user_id: skipped, creature_texts: run_creature_turns_after_skip(game) }
        else
          skipped = game.current_turn_user_id
          advance(game)
          { skipped_user_id: skipped, creature_texts: [] }
        end
      end

      # Pull a player out of the combat order (if fighting) and the normal
      # rotation. Used by the host bench control and by player departure.
      def remove_player_from_rotation(game, user_id)
        if game.in_combat? && game.player_state(user_id).dig("combat", "active")
          new_ps = game.player_state(user_id).dup
          new_ps["combat"] = nil
          new_ps.delete("waiting_for_combat_end")
          game.update_player_state(user_id, new_ps)
          remove_from_combat(game, user_id)
        end
        game.remove_from_turn_order(user_id)
      end

      # Returns a context-sensitive "not your turn" message.
      def waiting_message(game, user_id)
        ps = game.player_state(user_id)
        return "Waiting for combat to finish..." if ps["waiting_for_combat_end"]

        unless game.in_combat?
          order = game.turn_state["turn_order"] || []
          if order.any? && order.exclude?(user_id.to_i)
            return "You're out of the turn rotation. The host can add you back in."
          end
        end

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

        # After a host skip in combat: advance past the skipped combatant and
        # run creature turns until a player slot comes up or combat ends.
        # Returns names-only narration lines (no acting player to personalize).
        def run_creature_turns_after_skip(game)
          texts = []
          game.advance_combat_turn

          while game.in_combat?
            current = game.current_combatant
            break unless current
            break if current["type"] == "player"

            turn = ClassicGame::CreatureTurn.run(game, current["id"])
            texts << turn[:spectator] if turn[:spectator].present?
            break unless game.in_combat?

            game.advance_combat_turn
          end

          texts
        end

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
