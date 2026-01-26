# frozen_string_literal: true

class AiChatMessageJob
  include SuckerPunch::Job

  def perform(game_id)
    ActiveRecord::Base.connection_pool.with_connection do
      sleep(1)
      game = Game.find(game_id)

      ai_message = Message.create(game_id: game_id, content: "...")
      total_message = ""

      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
      stream = client.responses.stream(
        model: game.ai_config.model_name,
        input: game.messages_for_ai
      )

      stream.each do |event|
        next unless event.type.to_s == "response.output_text.delta"

        text_delta = event.delta
        total_message += text_delta if text_delta
        ai_message.update(content: total_message)
      end
    end
  end
end
