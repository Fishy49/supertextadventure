# AI Configurations

This directory contains AI configuration classes for different game types.

## Structure

Each AI configuration class should:

1. Initialize with a `game` instance
2. Implement `messages_for_ai` - returns an array of message hashes for the AI
3. Implement `model_name` - returns the model to use (e.g., "gpt-5-mini")
4. Implement `max_tokens_for_chapter` - returns the token limit before closing a chapter

## Example: Creating a New AI Config

```ruby
# app/lib/ai_configs/fantasy_rpg_config.rb
module AiConfigs
  class FantasyRpgConfig
    SYSTEM_PROMPT = <<~PROMPT.strip
      Your custom system prompt here...
    PROMPT

    MAX_TOKENS_FOR_AI_CHAPTER = 10000

    def initialize(game)
      @game = game
    end

    def messages_for_ai
      # Build and return message array
      [
        { role: "system", content: SYSTEM_PROMPT },
        # ... more messages
      ]
    end

    def model_name
      "gpt-5-mini" # or any other supported model
    end

    def max_tokens_for_chapter
      MAX_TOKENS_FOR_AI_CHAPTER
    end
  end
end
```

## Using a New Config

1. Create your config class in this directory
2. Update `Game#ai_config` to handle your new game type:

```ruby
def ai_config
  @ai_config ||= case game_type
                 when "chat_ai"
                   AiConfigs::ChatAiConfig.new(self)
                 when "fantasy_rpg"
                   AiConfigs::FantasyRpgConfig.new(self)
                 else
                   raise "Unknown game type: #{game_type}"
                 end
end
```

## Available Configs

- **ChatAiConfig** - Text adventure game master (used for "chat_ai" game type)
