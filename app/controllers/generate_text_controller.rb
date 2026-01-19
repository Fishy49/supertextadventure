# frozen_string_literal: true

class GenerateTextController < ApplicationController
  before_action :promptify

  def text
    client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
    response = client.responses.create(
      model: "gpt-5-mini",
      input: @prompt
    )
    render json: { generated_text: response.output_text }
  end

  private

    def promptify
      @prompt = <<-TEXT
		Generate a #{params[:length]} description in the style of #{params[:style]} that desribes a scene from the following user prompt: "#{params[:prompt]}"
      TEXT
    end
end
