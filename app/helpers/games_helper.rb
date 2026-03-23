# frozen_string_literal: true

module GamesHelper
  def game_type_options
    [
      ["Chat Mode", "chat"],
      ["Chat (AI)", "chat_ai"],
      ["Classic Mode", "classic"],
      ["Classic Mode (AI)", "classic_ai"]
    ]
  end

  def game_status_options
    [
      %w[Open open],
      %w[Closed closed]
    ]
  end

  def world_options
    World.all.map { |world| [world.name, world.id] }
  end
end
