# frozen_string_literal: true

module GamesHelper
  def game_type_options
    [
      %w[Free-Form freeform],
      %w[ChatGPT chatgpt]
    ]
  end

  def game_status_options
    [
      %w[Open open],
      %w[Closed closed]
    ]
  end
end
