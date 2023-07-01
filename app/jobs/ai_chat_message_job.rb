# frozen_string_literal: true

class AiChatMessageJob
  include SuckerPunch::Job

  def perform(game_id)
    ActiveRecord::Base.connection_pool.with_connection do
      game = Game.find(game_id)

      # Time to close a a chapter
      # no chapter created yet - let's do that first
      if game.current_token_count > Game::MAX_TOKENS_FOR_AI_CHAPTER && game.current_chapter.nil?
        # no chapter created yet - let's do that first
      end

      client = OpenAI::Client.new
      response = client.chat(
        parameters: {
          model: "gpt-4",
          messages: game.messages_for_ai
        }
      )
      ai_response = response.dig("choices", 0, "message", "content")

      Message.create(game_id: game_id, content: ai_response)
    end
  end
end
