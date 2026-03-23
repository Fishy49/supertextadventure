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

      # Create response message (will auto-broadcast via callback)
      Message.create!(
        game: game,
        content: result[:response]
        # NOTE: no game_user_id, so it's a "host" message from the game engine
      )
    end
  end
end
