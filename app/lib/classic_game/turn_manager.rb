# frozen_string_literal: true

module ClassicGame
  class TurnManager
    class << self
      # Set up turn order for a freshly started game.
      def initialize_turns(game, user_ids)
        game.game_state["turn_state"] = {
          "order" => user_ids.map(&:to_s),
          "current_index" => 0,
          "combat_waiters" => {}
        }
        game.save!
      end

      # Returns the user_id string for whoever holds the current turn,
      # or nil when no turn state has been initialized.
      def current_player(game)
        ts = turn_state(game)
        return nil unless ts

        ts["order"][ts["current_index"]]
      end

      # True when the given user is allowed to act right now.
      # Single-player games (no turn_state, or only one player) always return true.
      def user_can_act?(game, user_id)
        ts = turn_state(game)
        return true unless ts
        return true if ts["order"].size <= 1

        current_player(game) == user_id.to_s
      end

      # Move to the next non-waiting player. Wraps around.
      # No-op when no turn state exists.
      def advance(game)
        ts = turn_state(game)
        return unless ts

        order = ts["order"]
        return if order.empty?

        waiters = ts["combat_waiters"] || {}
        current_index = ts["current_index"]
        steps = 0

        loop do
          current_index = (current_index + 1) % order.size
          steps += 1
          break unless waiters.key?(order[current_index])
          break if steps >= order.size # all players waiting — stop at next anyway
        end

        ts["current_index"] = current_index
        game.save!
      end

      # Mark a player as waiting for combat in a given room to end.
      def add_combat_waiter(game, user_id, room_id)
        ts = turn_state(game)
        return unless ts

        ts["combat_waiters"] ||= {}
        ts["combat_waiters"][user_id.to_s] = room_id.to_s
        game.save!
      end

      # Remove a single combat waiter.
      def remove_combat_waiter(game, user_id)
        ts = turn_state(game)
        return unless ts

        ts["combat_waiters"]&.delete(user_id.to_s)
        game.save!
      end

      # Remove all combat waiters associated with a specific room.
      def clear_combat_waiters_for_room(game, room_id)
        ts = turn_state(game)
        return unless ts

        waiters = ts["combat_waiters"] || {}
        waiters.delete_if { |_uid, rid| rid == room_id.to_s }
        game.save!
      end

      # Returns a human-readable "waiting for X's turn" message.
      def waiting_message(game)
        player_id = current_player(game)
        name = character_name_for(game, player_id) || "another player"
        "It's #{name}'s turn. Please wait."
      end

      private

        def turn_state(game)
          game.game_state["turn_state"]
        end

        def character_name_for(game, user_id)
          return nil unless user_id
          return nil unless game.respond_to?(:game_users)

          gu = game.game_users.find { |u| u.user_id.to_s == user_id.to_s }
          gu&.character_name
        end
    end
  end
end
