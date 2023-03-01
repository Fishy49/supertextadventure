# frozen_string_literal: true

OPENAI_ENABLED = ENV.fetch("OPENAI_ACCESS_TOKEN", nil).present?

if OPENAI_ENABLED
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
    config.organization_id = ENV.fetch("OPENAI_ORGANIZATION_ID") # Optional.
  end
end
