# frozen_string_literal: true

class ClassicCommandJob
  include SuckerPunch::Job

  def perform(message_id)
    ActiveRecord::Base.connection_pool.with_connection do
      # Small delay to ensure user message broadcasts first
      sleep(0.1)

      message = Message.find(message_id)
      game = message.game

      # Execute the command through the classic game engine
      user = message.game_user&.user || User.find(game.created_by)
      result = ClassicGame::Engine.execute(
        game: game,
        user: user,
        command_text: message.content
      )

      broadcast_dice_roll(game, message, result)
      sync_classic_sidebar(game, user, message.game_user)

      # Determine which players should see the primary response
      primary_visible_to = players_in_acting_room(game, user)

      # Create primary response message
      Message.create!(
        game: game,
        content: result[:response],
        visible_to_user_ids: primary_visible_to,
        room_id: game.player_state(user.id)["current_room"]
        # NOTE: no game_user_id, so it's a "host" message from the game engine
      )

      # Process secondary messages (arrival/departure notices, give notifications, etc.)
      (result[:secondary_messages] || []).each do |sec|
        Message.create!(
          game: game,
          content: sec[:text],
          visible_to_user_ids: Array(sec[:visible_to]).map(&:to_s)
        )
      end
    end
  end

  private

    def players_in_acting_room(game, user)
      current_room = game.player_state(user.id)["current_room"]
      return [] unless current_room

      player_states = game.game_state["player_states"] || {}
      uids = player_states.filter_map { |uid, state| uid if state["current_room"] == current_room }

      # Empty array means "visible to all" — preserve single-player backward compatibility
      uids.size <= 1 ? [] : uids.map(&:to_s)
    end

    def broadcast_dice_roll(game, message, result)
      return unless result[:dice_roll]

      Message.create!(
        game: game,
        game_user: message.game_user,
        event_type: "roll",
        event_data: result[:dice_roll],
        content: ""
      )
    end

    def sync_classic_sidebar(game, user, game_user)
      return unless game_user && game.classic?

      player_state = game.player_state(user.id)
      new_health = player_state["health"]

      # Sync health without callbacks — the engine already reports health in output
      if new_health && new_health != game_user.current_health
        game_user.update_columns(current_health: new_health) # rubocop:disable Rails/SkipsModelValidations
        game_user.reload
      end

      # Broadcast updated player partial (health, room, etc.)
      game_user.broadcast_replace_to(game, :players, target: "game_user_#{game_user.id}",
                                                     partial: "/games/player",
                                                     locals: { game_user: game_user, for_host: false })
    end
end
