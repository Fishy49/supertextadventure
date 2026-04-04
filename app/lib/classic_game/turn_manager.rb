# frozen_string_literal: true

module ClassicGame
  class TurnManager
    class << self
      # Returns true when it is this player's turn, or when there is no turn
      # state (single-player / legacy games — always allow).
      def can_act?(game, user_id)
        ts = game.game_state["turn_state"]
        return true unless ts

        game.current_turn_user_id == user_id.to_s
      end

      # Initialise turn order from the game's joined players (DB only).
      # Called from GameUser after_create_commit for classic games.
      def initialize_for_game(game)
        user_ids = game.game_users.order(:id).pluck(:user_id).map(&:to_s)
        game.initialize_turn_order(user_ids)
      end

      # Advance the game to the next player's turn.
      def advance(game)
        game.advance_turn
      end

      # Returns a human-readable message telling the waiting player whose
      # turn it currently is.
      def waiting_message(game, _user_id)
        current_id = game.current_turn_user_id
        name = player_name(game, current_id)
        "It's #{name}'s turn. Please wait..."
      end

      # Mark a player as having fled combat so they are skipped in turn order
      # until combat ends.
      def handle_flee(game, user_id)
        game.player_fled_combat(user_id)
      end

      # Re-enable all fled players once combat is over.
      def handle_combat_end(game)
        game.combat_ended
      end

      private

        def player_name(game, user_id)
          stored = game.game_state.dig("player_names", user_id.to_s)
          return stored if stored

          if game.respond_to?(:game_users)
            gu = game.game_users.find_by(user_id: user_id)
            return gu.character_name if gu
          end

          "Player #{user_id}"
        end
    end
  end
end
