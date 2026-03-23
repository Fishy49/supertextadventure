# frozen_string_literal: true

# The official OpenAI gem doesn't use global configuration.
# API keys are passed directly to OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

# Check if OpenAI is configured
OPENAI_ENABLED = ENV.fetch("OPENAI_API_KEY", nil).present?
