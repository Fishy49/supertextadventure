# frozen_string_literal: true

module ClassicGame
  # Generates secondary messages for players who are affected by another
  # player's action but are not the one who issued the command.
  class MultiplayerNotifier
    class << self
      # Returns an array of { user_ids:, content: } hashes for players who are
      # in the same room as the acting player and should see their command + result.
      def observer_messages(game, acting_user_id, command_text, result)
        room_id = game.player_state(acting_user_id)["current_room"]
        others = game.players_in_room(room_id).reject { |uid| uid == acting_user_id.to_s }
        return [] if others.empty?

        actor_name = player_name(game, acting_user_id)
        content = "[#{actor_name}]: #{command_text}\n\n#{result[:response]}"
        [{ user_ids: others, content: content }]
      end

      # Returns a single { user_ids:, content: } hash for players already in
      # the destination room when another player arrives, or nil if the room
      # is empty.
      def arrival_message(game, arriving_user_id, room_id)
        others = game.players_in_room(room_id).reject { |uid| uid == arriving_user_id.to_s }
        return nil if others.empty?

        name = player_name(game, arriving_user_id)
        { user_ids: others, content: "[#{name}] has arrived." }
      end

      # Returns an array of { user_ids:, content: } hashes for players in rooms
      # whose exits reference a flag that just changed.
      def global_event_messages(game, flag_changes, acting_user_id)
        return [] if flag_changes.empty?

        messages = []
        world = game.world_snapshot

        flag_changes.each_key do |flag_name|
          world["rooms"]&.each do |room_id, room_def|
            (room_def["exits"] || {}).each_value do |exit_data|
              next unless exit_data.is_a?(Hash)
              next unless exit_data["requires_flag"] == flag_name

              room_players = game.players_in_room(room_id).reject { |uid| uid == acting_user_id.to_s }
              next if room_players.empty?

              content = exit_data["remote_event_msg"] || "Something changes in the distance..."
              messages << { user_ids: room_players, content: content }
            end
          end
        end

        messages
      end

      # Returns a turn-status string shown in the player's UI.
      def waiting_indicator(game, user_id)
        if ClassicGame::TurnManager.can_act?(game, user_id)
          "It's your turn!"
        else
          current_id = game.current_turn_user_id
          name = player_name(game, current_id)
          "Waiting for #{name}'s turn..."
        end
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
