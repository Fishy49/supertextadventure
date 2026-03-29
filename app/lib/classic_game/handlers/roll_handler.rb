# frozen_string_literal: true

module ClassicGame
  module Handlers
    class RollHandler < BaseHandler
      def handle(command)
        # If no pending roll, reject
        return failure("Nothing to roll for.") unless pending_roll?

        # If command is not :roll, prompt the player
        return failure("You need to ROLL first. Type ROLL to roll the dice.") unless command[:verb] == :roll

        resolve_roll
      end

      private

        def resolve_roll
          roll_spec = player_state["pending_roll"]
          dc = roll_spec["dc"]
          dice_notation = roll_spec["dice"] || "1d20"

          # Roll the dice
          result = DiceRoll.new(dice_notation)
          rolled = result.total

          # Determine outcome
          succeeded = rolled >= dc
          branch = succeeded ? roll_spec["on_success"] : roll_spec["on_failure"]

          # Execute directives from the winning branch
          execute_roll_directives(branch, player_state["current_room"])

          # Clear pending roll and consume item if applicable
          new_state = player_state.dup
          new_state.delete("pending_roll")
          if should_consume?(roll_spec, succeeded)
            new_state["inventory"] = (new_state["inventory"] || []) - [roll_spec["source_item"]]
          end
          update_player_state(new_state)

          # Build response
          outcome = succeeded ? "Success!" : "Failed."
          response_text = "You rolled a #{rolled}. #{outcome}\n#{branch['message']}"

          success(response_text).merge(dice_roll: result)
        end

        def should_consume?(roll_spec, succeeded)
          consume_on = roll_spec["consume_on"]
          return false unless consume_on

          consume_on == "any" ||
            (consume_on == "failure" && !succeeded) ||
            (consume_on == "success" && succeeded)
        end
    end
  end
end
