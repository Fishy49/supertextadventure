# frozen_string_literal: true

class ClassicCommandJob < ApplicationJob
  queue_as :default

  def perform(message_id)
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
    game.broadcast_text_forms

    dispatch_result_messages(game, user, result)
  end

  # Route an engine result to the right audience-scoped messages. Public so
  # integration tests exercise the real dispatch rather than a copy of it.
  def dispatch_result_messages(game, user, result)
    state_changes = result[:state_changes] || {}
    if state_changes[:moved]
      broadcast_movement_messages(game, user, result, state_changes)
    elsif state_changes[:give_to_player]
      broadcast_give_messages(game, user, result, state_changes[:give_to_player])
    elsif state_changes[:spectator_response].present?
      broadcast_combat_messages(game, user, result, state_changes)
    elsif state_changes[:turn_blocked]
      # Off-turn feedback is for the blocked player alone.
      if result[:response].present?
        Message.create!(game: game, content: result[:response],
                        visible_to_user_ids: [user.id])
      end
    elsif result[:response].present?
      Message.create!(game: game, content: result[:response])
    end
  end

  private

    # The host is the GM: they get every scoped narration meant for observers,
    # unless they're the acting player themselves.
    def audience_with_host(game, user_ids, actor_id)
      ids = Array(user_ids).map(&:to_i)
      host_id = game.created_by
      ids << host_id if host_id && host_id != actor_id.to_i
      ids.uniq
    end

    def broadcast_movement_messages(game, user, result, state_changes)
      Message.create!(
        game: game,
        content: result[:response],
        visible_to_user_ids: [user.id]
      )

      if state_changes[:departure_text]
        audience = audience_with_host(game, state_changes[:departure_audience] || [], user.id)
        if audience.any?
          Message.create!(
            game: game,
            content: state_changes[:departure_text],
            visible_to_user_ids: audience
          )
        end
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

      return unless give_data[:bystander_text]

      audience = audience_with_host(game, give_data[:bystander_audience] || [], user.id)
      return if audience.empty?

      Message.create!(
        game: game,
        content: give_data[:bystander_text],
        visible_to_user_ids: audience
      )
    end

    def broadcast_combat_messages(game, user, result, state_changes)
      if result[:response].present?
        Message.create!(game: game, content: result[:response],
                        visible_to_user_ids: [user.id])
      end

      audience = audience_with_host(game, state_changes[:spectator_audience] || [], user.id)
      return if audience.empty?

      Message.create!(
        game: game,
        content: state_changes[:spectator_response],
        visible_to_user_ids: audience
      )
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

      # Sync health without callbacks - the engine already reports health in output
      if new_health && new_health != game_user.current_health
        game_user.update_columns(current_health: new_health) # rubocop:disable Rails/SkipsModelValidations
        game_user.reload
      end

      # Broadcast updated player partial (health, room, etc.)
      game_user.broadcast_replace_to(game, :players, target: "game_user_#{game_user.id}",
                                                     partial: "/games/player",
                                                     locals: { game_user: game_user, for_host: false })

      # Broadcast updated inventory partial on both player and host streams - when a
      # host is also a player (dev mode), they only subscribe to :host_players.
      game_user.broadcast_replace_to(game, :players, target: "player_inventory_#{user.id}",
                                                     partial: "/games/inventory",
                                                     locals: { game: game, user: user })
      game_user.broadcast_replace_to(game, :host_players, target: "player_inventory_#{user.id}",
                                                          partial: "/games/inventory",
                                                          locals: { game: game, user: user })
    end
end
