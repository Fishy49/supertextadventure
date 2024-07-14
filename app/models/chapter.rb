# frozen_string_literal: true

class Chapter < ApplicationRecord
  belongs_to :game
  belongs_to :first_message, class_name: "Message", optional: true
  belongs_to :last_message, class_name: "Message", optional: true

  CHAPTER_PROMPT = <<-INSTRUCTION
    Please create a brief summary of all previous messages as a chapter summary and give the chapter a name.
    Respond with the name of the chapter first, a colon, and then the chapter summary. Include all names of
    any characters so far.
  INSTRUCTION

  def all_messages
    Message.for_ai
           .where(game_id: game.id)
           .where(id: first_message.id..)
           .where(id: ..(last_message&.id || 9_999_999))
           .order(id: :asc)
  end

  def close!
    Message.create(game_id: game_id, content: "Please Wait. Closing Chapter #{number}...")

    update(last_message_id: game.messages.last.id)

    client = OpenAI::Client.new

    chat_log = all_messages.map { |m| { role: game.role_for_ai_message(m), content: m.content } }
    chat_log << { role: "user", content: CHAPTER_PROMPT }

    response = client.chat(parameters: { model: "gpt-4", messages: chat_log })
    ai_response = response.dig("choices", 0, "message", "content")

    chapter_name, summary = parse_chapter_info(ai_response)
    update(name: chapter_name, summary: summary)

    chapter_message = Message.create(game_id: game_id, content: "Thus concludes #{chapter_name}")

    create_next_chapter(chapter_message)
  end

  private

    def parse_chapter_info(ai_response)
      response_parts = ai_response.split(":")
      chapter_name = if response_parts.count > 2
                       response_parts.take(response_parts.count - 1).join(" - ")
                     else
                       response_parts.first
                     end
      summary = response_parts.last
      [chapter_name, summary]
    end

    def create_next_chapter(starting_message)
      Chapter.create(
        game_id: game.id,
        number: number + 1,
        first_message_id: starting_message.id
      )
    end
end
