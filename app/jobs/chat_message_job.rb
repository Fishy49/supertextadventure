# frozen_string_literal: true

class ChatMessageJob
  include SuckerPunch::Job

  def perform(game_id)
    game = Game.find(game_id)
    client = OpenAI::Client.new
    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: game.messages_for_ai
      }
    )
    ai_response = response.dig("choices", 0, "message", "content")

    Message.create(game_id: game_id, content: ai_response)
  end
end
