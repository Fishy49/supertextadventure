# frozen_string_literal: true

module ClassicGame
  class Engine
    class << self
      def execute(game:, user:, command_text:)
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

      private

      def get_handler(verb, game:, user_id:)
        handler_class = case verb
                        when :go, :enter, :leave, :climb
                          ClassicGame::Handlers::MovementHandler
                        when :look, :examine, :inventory
                          ClassicGame::Handlers::ExamineHandler
                        when :take, :drop, :use
                          ClassicGame::Handlers::ItemHandler
                        when :talk, :attack, :give
                          ClassicGame::Handlers::InteractHandler
                        when :help
                          return help_handler
                        else
                          nil
                        end

        handler_class&.new(game: game, user_id: user_id)
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
                INTERACT: TALK TO [npc], ATTACK [creature], GIVE [item] TO [npc]

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
