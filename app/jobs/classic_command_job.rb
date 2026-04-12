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
      broadcast_text_form_updates(game)

      state_changes = result[:state_changes] || {}
      if state_changes[:moved]
        broadcast_movement_messages(game, user, result, state_changes)
      elsif state_changes[:give_to_player]
        broadcast_give_messages(game, user, result, state_changes[:give_to_player])
      elsif result[:response].present?
        Message.create!(game: game, content: result[:response])
      end
    end
  end

  private

    def broadcast_movement_messages(game, user, result, state_changes)
      Message.create!(
        game: game,
        content: result[:response],
        visible_to_user_ids: [user.id]
      )

      if state_changes[:departure_text] && state_changes[:departure_audience]&.any?
        Message.create!(
          game: game,
          content: state_changes[:departure_text],
          visible_to_user_ids: state_changes[:departure_audience]
        )
      end

      return unless state_changes[:arrival_text] && state_changes[:arrival_audience]&.any?

      Message.create!(
        game: game,
        content: state_changes[:arrival_text],
        visible_to_user_ids: state_changes[:arrival_audience]
      )
    end

    def broadcast_give_messages(game, user, result, give_data)
      Message.create!(
        game: game,
        content: result[:response],
        visible_to_user_ids: [user.id]
      )

      Message.create!(
        game: game,
        content: give_data[:receiver_text],
        visible_to_user_ids: [give_data[:receiver_user_id]]
      )

      return unless give_data[:bystander_text] && give_data[:bystander_audience]&.any?

      Message.create!(
        game: game,
        content: give_data[:bystander_text],
        visible_to_user_ids: give_data[:bystander_audience]
      )
    end

    def broadcast_text_form_updates(game)
      return unless game.classic?

      user_ids = game.game_users.pluck(:user_id)
      user_ids << game.created_by unless user_ids.include?(game.created_by)
      user_ids.uniq.each do |uid|
        user = User.find(uid)
        Turbo::StreamsChannel.broadcast_replace_to(
          game, "turn_for_#{uid}",
          target: "text_form_content",
          partial: "games/text_form",
          locals: { game: game, user: user }
        )
      end
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
