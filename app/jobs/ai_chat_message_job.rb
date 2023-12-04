# frozen_string_literal: true

class AiChatMessageJob
  include SuckerPunch::Job

  def perform(game_id)
    ActiveRecord::Base.connection_pool.with_connection do
      game = Game.find(game_id)

      ai_message = Message.create(game_id: game_id, content: "...")
      total_message = ""
      OpenAI::Client.new.chat(
        parameters: {
          model: "gpt-4-1106-preview", messages: game.messages_for_ai,
          stream: proc do |chunk, _bytesize|
            next_chunk = chunk.dig("choices", 0, "delta", "content")
            total_message = "#{total_message}#{next_chunk}"
            ai_message.update(content: total_message)
          end
        }
      )
    end
  end
end
