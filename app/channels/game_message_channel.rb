class GameMessageChannel < ApplicationCable::Channel
  def subscribed
    game = Game.find(params[:game_id])
    stream_for game.id
  end
end
