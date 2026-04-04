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

      # Create response message (will auto-broadcast via callback)
      Message.create!(
        game: game,
        content: result[:response]
        # NOTE: no game_user_id, so it's a "host" message from the game engine
      )

      create_multiplayer_messages(game, user, result)
    end
  end

  private

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

    def create_multiplayer_messages(game, user, result)
      events = result[:multiplayer_events]
      return unless events

      # Observer messages — players in same room who see the action
      (events[:observer_messages] || []).each do |event|
        Message.create!(
          game: game,
          content: event[:content],
          visible_to_user_ids: event[:user_ids].map(&:to_i)
        )
      end

      # Global event messages — remote players affected by flag changes
      (events[:global_event_messages] || []).each do |event|
        Message.create!(
          game: game,
          content: event[:content],
          visible_to_user_ids: event[:user_ids].map(&:to_i)
        )
      end

      # Arrival messages when a player moves into a room with others
      if result.dig(:state_changes, :arrived_in_room)
        arrival = ClassicGame::MultiplayerNotifier.arrival_message(
          game, user.id, result.dig(:state_changes, :arrived_in_room)
        )
        if arrival
          Message.create!(
            game: game,
            content: arrival[:content],
            visible_to_user_ids: arrival[:user_ids].map(&:to_i)
          )
        end
      end
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
