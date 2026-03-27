# frozen_string_literal: true

module ClassicGame
  class Engine
    class << self
      def execute(game:, user:, command_text:)
        # Check if we're waiting for restart confirmation
        return handle_restart_confirmation(game, command_text) if game.game_state["pending_restart"]

        # Check if a dice roll is pending — route all input to RollHandler
        ps = game.player_state(user.id)
        if ps["pending_roll"]
          return ClassicGame::Handlers::RollHandler.new(game: game, user_id: user.id).handle(
            ClassicGame::CommandParser.parse(command_text)
          )
        end

        # Parse the command
        command = CommandParser.parse(command_text)

        # Route to appropriate handler
        handler = get_handler(command[:verb], game: game, user_id: user.id)

        if handler
          handler.handle(command)
        else
          unknown_command_response(command)
        end
      rescue StandardError => e
        Rails.logger.error("ClassicGame::Engine error: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        error_response("Something went wrong: #{e.message}")
      end

      def validate_world_data(world_data)
        errors = []
        items = world_data["items"] || {}
        items.each do |item_id, item_def|
          next unless item_def.is_a?(Hash) && item_def["dice_roll"]

          roll = item_def["dice_roll"]
          unless roll["on_success"].is_a?(Hash) && roll["on_failure"].is_a?(Hash)
            errors << "Item '#{item_id}' has a dice_roll missing on_success or on_failure."
          end
        end
        errors
      end

      private

        def get_handler(verb, game:, user_id:)
          # PRIORITY: Route to CombatHandler if in combat
          player_state = game.player_state(user_id)
          if player_state.dig("combat", "active")
            return ClassicGame::Handlers::CombatHandler.new(game: game, user_id: user_id)
          end

          handler_class = case verb
                          when :go, :enter, :leave, :climb
                            ClassicGame::Handlers::MovementHandler
                          when :look, :examine, :inventory
                            ClassicGame::Handlers::ExamineHandler
                          when :take, :drop, :use
                            ClassicGame::Handlers::ItemHandler
                          when :open, :close
                            ClassicGame::Handlers::ContainerHandler
                          when :talk, :attack, :give
                            ClassicGame::Handlers::InteractHandler
                          when :roll
                            ClassicGame::Handlers::RollHandler
                          when :restart
                            ClassicGame::Handlers::RestartHandler
                          when :defend, :flee
                            # These should only be available in combat, but just in case
                            nil
                          when :help
                            return help_handler
                          end

          handler_class&.new(game: game, user_id: user_id)
        end

        def handle_restart_confirmation(game, command_text)
          response_text = command_text.strip.downcase

          if %w[yes y].include?(response_text)
            # Delete all messages
            game.messages.destroy_all

            # Reset the game state - re-snapshot the world and clear all player/room states
            game.update!(game_state: {
                           "world_snapshot" => game.world.world_data.deep_dup,
                           "player_states" => {},
                           "room_states" => {},
                           "global_flags" => {},
                           "container_states" => {}
                         })

            # Generate fresh starting room description
            starting_room_id = game.world_snapshot.dig("meta",
                                                       "starting_room") || game.world_snapshot["rooms"]&.keys&.first
            room_def = game.world_snapshot.dig("rooms", starting_room_id)

            lines = []
            lines << "=== GAME RESTARTED ==="
            lines << ""
            lines << "=== #{room_def['name']} ==="
            lines << ""
            lines << room_def["description"]

            # List exits
            exits = room_def["exits"] || {}
            if exits.any?
              lines << ""
              lines << "Exits: #{exits.keys.map { |k| k.to_s.upcase }.join(', ')}"
            end

            {
              success: true,
              response: lines.join("\n"),
              state_changes: { full_reset: true }
            }
          elsif %w[no n].include?(response_text)
            # Cancel the restart
            game.game_state.delete("pending_restart")
            game.save!

            {
              success: true,
              response: "Restart cancelled. The game continues...",
              state_changes: {}
            }
          else
            # Invalid response, ask again
            {
              success: false,
              response: "Please answer YES or NO.",
              state_changes: {}
            }
          end
        end

        def help_handler
          # Simple static help handler that doesn't need game state
          Class.new do
            def handle(_command)
              {
                success: true,
                response: <<~HELP,
                  Available commands:

                  MOVEMENT: GO/MOVE [direction], N/S/E/W, ENTER, LEAVE, CLIMB
                  OBSERVE: LOOK, EXAMINE [object], INVENTORY/I
                  ITEMS: TAKE/GET [item], DROP [item], USE [item] ON [target]
                  CONTAINERS: OPEN [container], CLOSE [container]
                  INTERACT: TALK TO [npc], ATTACK [creature], GIVE [item] TO [npc]
                  COMBAT: ATTACK, DEFEND, FLEE, USE [item] (while in combat)
                  GAME: RESTART (reset game to beginning)

                  Directions: NORTH/N, SOUTH/S, EAST/E, WEST/W, UP/U, DOWN/D, NE, NW, SE, SW

                  Tips: You can use shortcuts (N instead of NORTH, I instead of INVENTORY)
                HELP
                state_changes: {}
              }
            end
          end.new
        end

        def unknown_command_response(command)
          {
            success: false,
            response: "I don't understand '#{command[:raw]}'. Type HELP for available commands.",
            state_changes: {}
          }
        end

        def error_response(message)
          {
            success: false,
            response: message,
            state_changes: {}
          }
        end
    end
  end
end
