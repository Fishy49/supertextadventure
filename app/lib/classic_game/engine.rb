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
          result = ClassicGame::Handlers::RollHandler.new(game: game, user_id: user.id).handle(
            ClassicGame::CommandParser.parse(command_text)
          )
          result = process_npc_movement(game, user, result)
          advance_turn_if_ready(game, user)
          return result
        end

        # Check turn order — block off-turn players
        unless TurnManager.can_act?(game, user.id)
          return {
            success: false,
            response: TurnManager.waiting_message(game, user.id),
            state_changes: { turn_blocked: true }
          }
        end

        # Parse the command
        command = CommandParser.parse(command_text)

        # Route to appropriate handler
        handler = get_handler(command[:verb], game: game, user_id: user.id)

        result = if handler
                   handler.handle(command)
                 else
                   unknown_command_response(command)
                 end

        # If a player's combat action consumed a turn, advance the combat
        # order past them and run any creature turns that follow.
        if game.in_combat? && result.dig(:state_changes, :combat_turn_consumed)
          result = run_combat_turns(game, result, advance_first: true, acting_user_id: user.id)
        end

        # Aggro may start combat mid-action; run creature turns from the
        # current slot (combat_current_index is on the aggressor creature).
        result = check_aggressive_creatures(game, user, command, result)
        if game.in_combat? && result.dig(:state_changes, :aggro_started_combat)
          result = run_combat_turns(game, result, advance_first: false, acting_user_id: user.id)
        end

        result = process_npc_movement(game, user, result)
        advance_turn_if_ready(game, user) unless game.in_combat?
        result
      rescue StandardError => e
        Rails.logger.error("ClassicGame::Engine error: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        error_response("Something went wrong: #{e.message}")
      end

      VALID_CONSUME_ON = %w[failure success any].freeze

      def validate_world_data(world_data)
        errors = []
        items = world_data["items"] || {}
        items.each do |item_id, item_def|
          next unless item_def.is_a?(Hash) && item_def["dice_roll"]

          roll = item_def["dice_roll"]
          unless roll["on_success"].is_a?(Hash) && roll["on_failure"].is_a?(Hash)
            errors << "Item '#{item_id}' has a dice_roll missing on_success or on_failure."
          end

          next unless roll["consume_on"] && VALID_CONSUME_ON.exclude?(roll["consume_on"])

          error_text = "Item '#{item_id}' has invalid consume_on '#{roll['consume_on']}'"
          error_text += " (must be: #{VALID_CONSUME_ON.join(', ')})."
          errors << error_text
        end
        errors
      end

      private

        def advance_turn_if_ready(game, user)
          return if (game.turn_state["turn_order"] || []).length <= 1

          ps = game.player_state(user.id)
          return if ps["pending_roll"].present?

          TurnManager.advance(game)
        end

        def process_npc_movement(game, user, result)
          messages = ClassicGame::NpcMovementProcessor.process(game: game, user_id: user.id)
          return result if messages.empty?

          combined = result[:response]
          messages.each { |msg| combined += "\n\n#{msg}" }
          result.merge(response: combined)
        end

        # Advance combat turns and fire creature actions until the next
        # combatant is a player (waiting for input) or combat ends.
        def run_combat_turns(game, result, advance_first:, acting_user_id: nil)
          return result unless game.in_combat?

          output = [result[:response]].compact_blank
          game.advance_combat_turn if advance_first

          while game.in_combat?
            current = game.current_combatant
            break unless current
            break if current["type"] == "player"

            creature_text = ClassicGame::CreatureTurn.run(
              game, current["id"], acting_user_id: acting_user_id
            )
            output << creature_text if creature_text.present?
            break unless game.in_combat?

            game.advance_combat_turn
          end

          result.merge(response: output.join("\n\n"))
        end

        def check_aggressive_creatures(game, user, command, result)
          return result if game.in_combat?

          ps = game.player_state(user.id)

          ps["room_actions"] ||= {}
          room_id = ps["current_room"]
          ps["room_actions"][room_id] = (ps["room_actions"][room_id] || 0) + 1
          game.update_player_state(user.id, ps)

          room_state = game.room_state(room_id)
          creatures = room_state["creatures"] || []
          world = game.world_snapshot

          creatures.each do |creature_id|
            creature_def = world.dig("creatures", creature_id)
            next unless creature_def
            next unless creature_def["hostile"]
            next if should_defer_attack?(creature_def, ps, room_id, command, creature_id)

            # Start combat with the creature at the current combat slot so
            # the engine's combat-turn loop fires its first attack.
            ClassicGame::TurnManager.enter_combat_mode(
              game, room_id, creature_id, starting_combatant: :creature
            )

            aggro_text = creature_def["aggro_text"] || "The #{creature_def['name']} attacks!"
            combined = "#{result[:response]}\n\n#{aggro_text}"
            return result.merge(
              response: combined,
              state_changes: (result[:state_changes] || {}).merge(aggro_started_combat: true)
            )
          end

          result
        end

        def should_defer_attack?(creature_def, player_state, room_id, command, creature_id)
          condition = creature_def["attack_condition"]

          # No condition = attack immediately on any action
          return false unless condition

          if condition["moves"]
            actions = player_state.dig("room_actions", room_id) || 0
            return actions < condition["moves"]
          end

          if condition["room_entries"]
            entries = player_state.dig("room_entries", room_id) || 0
            return entries < condition["room_entries"]
          end

          if condition["on_talk"]
            return !(command[:verb] == :talk && talk_targets_creature?(command, creature_id, creature_def))
          end

          # Unknown condition type — don't attack
          true
        end

        def talk_targets_creature?(command, creature_id, creature_def)
          target = command[:modifier].presence || command[:target]
          return false if target.blank?

          target_lower = target.downcase
          return true if creature_id.downcase.include?(target_lower) || target_lower.include?(creature_id.downcase)

          keywords = creature_def["keywords"] || []
          keywords.any? { |kw| kw.downcase.include?(target_lower) || target_lower.include?(kw.downcase) }
        end

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
                           "container_states" => {},
                           "turn_count" => 0,
                           "npc_movement" => {},
                           "turn_state" => { "turn_order" => [], "current_index" => 0 }
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
