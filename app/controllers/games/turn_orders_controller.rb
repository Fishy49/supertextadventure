# frozen_string_literal: true

module Games
  # Host-only controls over the classic-game turn rotation: reorder the
  # rotation, skip the active turn, and bench/unbench players. Every state
  # change happens under the game row lock so it can't clobber a command
  # the engine is executing concurrently.
  class TurnOrdersController < ApplicationController
    before_action :set_game
    before_action :require_host!

    # PATCH /games/:game_id/turn-order  params: user_ids[] in the new order
    def update
      user_ids = Array(params[:user_ids]).map(&:to_i)
      valid = false
      @game.with_lock do
        current = @game.turn_state["turn_order"] || []
        valid = !@game.in_combat? && user_ids.sort == current.sort
        @game.reorder_turns(user_ids) if valid
      end
      return head :unprocessable_content unless valid

      announce("**The host changed the turn order.**")
      finish_turn_change
    end

    # POST /games/:game_id/turn-order/skip
    def skip
      outcome = nil
      @game.with_lock do
        outcome = ClassicGame::TurnManager.host_skip(@game)
      end

      if outcome[:skipped_user_id]
        name = @game.character_name_for(outcome[:skipped_user_id]) || "the current player"
        announce("**The host skipped #{name}'s turn.**")
      end
      announce_creature_turns(outcome[:creature_texts])
      finish_turn_change
    end

    # POST /games/:game_id/turn-order/bench/:user_id
    def bench
      uid = params[:user_id].to_i
      @game.with_lock do
        ClassicGame::TurnManager.remove_player_from_rotation(@game, uid)
      end

      name = @game.character_name_for(uid) || "A player"
      announce("**The host benched #{name}.**")
      finish_turn_change
    end

    # POST /games/:game_id/turn-order/unbench/:user_id
    def unbench
      uid = params[:user_id].to_i
      @game.with_lock do
        @game.add_to_turn_order(uid)
      end

      name = @game.character_name_for(uid) || "A player"
      announce("**#{name} is back in the turn rotation.**")
      finish_turn_change
    end

    private

      def set_game
        @game = Game.find_by!(uuid: params.expect(:game_id))
      end

      def require_host!
        head :forbidden unless @game.host?(current_user)
      end

      def announce(text)
        Message.create!(game: @game, content: text)
      end

      # Creature turns fired by a combat skip: narration goes to players in
      # the combat room plus the host, matching the engine's spectator rule.
      def announce_creature_turns(texts)
        return if texts.blank?

        room_id = @game.combat_state&.dig("room_id")
        audience = room_id ? @game.players_in_room(room_id).keys : @game.all_player_user_ids
        audience = (audience + [@game.created_by]).uniq
        Message.create!(game: @game, content: texts.join("\n\n"), visible_to_user_ids: audience)
      end

      def finish_turn_change
        @game.broadcast_text_forms
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "host_turn_panel",
              partial: "games/turn_panel",
              locals: { game: @game }
            )
          end
          format.html { redirect_to game_path(@game) }
        end
      end
  end
end
