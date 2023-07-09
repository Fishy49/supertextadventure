# frozen_string_literal: true

class AiChatMessageJob
  include SuckerPunch::Job

  def perform(game_id)
    ActiveRecord::Base.connection_pool.with_connection do
      game = Game.find(game_id)

      ai_message = Message.create(game_id: game_id, content: " ")
      client = OpenAI::Client.new
      client.chat(
        parameters: {
          model: "gpt-4",
          messages: game.messages_for_ai,
          stream: proc do |chunk, _bytesize|
            next_chunk = chunk.dig("choices", 0, "delta", "content")
            ai_message.update(content: next_chunk)
          end
        }
      )
    end
  end
end
