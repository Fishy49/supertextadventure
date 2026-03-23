# frozen_string_literal: true

module ClassicGame
  module Handlers
    class RestartHandler < BaseHandler
      def self.keywords
        %w[restart reset]
      end

      def handle(_command)
        # Set pending restart flag in game state
        game.game_state["pending_restart"] = true
        game.save!

        {
          success: true,
          response: "Restart? You will lose all progress! Continue? (YES/NO)",
          state_changes: {}
        }
      end
    end
  end
end
