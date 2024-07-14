# frozen_string_literal: true

class GenerateTextController < ApplicationController
  before_action :promptify

  def text
    response = OpenAI::Client.new.chat(
        parameters: {
          model: "gpt-4o",
          messages: [{ role: "user", content: @prompt }]
        }
      )
    render json: { generated_text: response.dig("choices", 0, "message", "content") }
  end

  private

    def promptify
      @prompt = <<-TEXT
		Generate a #{params[:length]} description in the style of #{params[:style]} that desribes a scene from the following user prompt: "#{params[:prompt]}"
      TEXT
    end
end
