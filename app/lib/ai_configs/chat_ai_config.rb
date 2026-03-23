# frozen_string_literal: true

module AiConfigs
  class ChatAiConfig
    SYSTEM_PROMPT = <<~PROMPT.strip
      You are the computer in a text-based adventure game. Your role is to narrate the story, describe environments,
      control NPCs, and adjudicate the outcomes of player actions.

      CORE RULES:
      - Keep ALL responses brief and succinct (2-4 sentences maximum)
      - This is fiction: violence, combat, damage, and death are permitted as part of the narrative
      - Never break character or reference that this is a game
      - Describe what players see, hear, and experience - don't tell them what they do
      - When players attempt challenging actions, ask them to roll a d20 by typing "/ROLL 1D20"
      - Don't specify ability types or skill names - just ask for "a d20 roll" for any challenge
      - NEVER reveal the difficulty class (DC) to players - keep it secret
      - Wait for dice roll results before narrating outcomes
      - If a player doesn't respond with a roll after being asked, remind them firmly to use "/ROLL 1D20"
      - Natural 20 is a critical success, Natural 1 is a critical failure
      - Never assume or invent dice roll results - always wait for the player's actual roll

      TONE:
      - Be descriptive but concise
      - Create tension and drama
      - Respond to player agency - let them drive the story
      - Use vivid sensory details

      Remember: You are the game master, not a player. Facilitate their adventure, don't play it for them.
    PROMPT

    MAX_TOKENS_FOR_AI_CHAPTER = 7500

    def initialize(game)
      @game = game
    end

    def messages_for_ai
      chat_log = [
        { role: "system", content: "#{SYSTEM_PROMPT}\n\nCampaign: #{@game.name}" }
      ]

      chat_log += chapter_summaries
      chat_log += current_messages_formatted

      chat_log
    end

    def model_name
      "gpt-5-mini"
    end

    def max_tokens_for_chapter
      MAX_TOKENS_FOR_AI_CHAPTER
    end

    private

      def chapter_summaries
        summaries = []
        return summaries if @game.complete_chapters.blank?

        @game.complete_chapters.each do |chapter|
          summaries << {
            role: "assistant",
            content: "#{chapter.name}: #{chapter.summary}"
          }
        end
        summaries
      end

      def current_messages_formatted
        formatted = []

        @game.current_messages.for_ai.each do |message|
          # Skip events except for roll events
          next if message.event? && message.event_type != "roll"

          content = format_message_content(message)
          role = determine_role(message)

          formatted << { role: role, content: content }
        end

        formatted
      end

      def format_message_content(message)
        if message.player_message?
          "[#{message.display_name}] #{message.content}"
        elsif message.event_type == "roll"
          message.roll_result_message_for_ai
        else
          message.content
        end
      end

      def determine_role(message)
        return "user" if message.player_message?
        return "assistant" if message.host_message?
        return "system" if message.is_system_message?
        return "user" if message.event_type == "roll"

        "user" # default
      end
  end
end
