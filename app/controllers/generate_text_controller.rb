# frozen_string_literal: true

class GenerateTextController < ApplicationController
  before_action :promptify

  def text
    client = OpenAI::Client.new
    response = client.completions(
      parameters: {
        model: "text-davinci-003",
        prompt: @prompt,
        max_tokens: 200
      }
    )

    render json: { generated_text: response["choices"].first["text"] }
  end

  private

    def promptify
      @prompt = <<-TEXT
		Generate a #{params[:length]} description in the style of #{params[:style]} from the following user prompt: "#{params[:prompt]}"
      TEXT
    end
end
