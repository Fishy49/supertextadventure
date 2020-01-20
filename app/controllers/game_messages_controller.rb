class GameMessagesController < ApplicationController
  def create
    previous_message_username = GameMessage.where(game_id: game_message_params[:game_id]).last.user.username
    @game_message = GameMessage.create game_message_params.merge(user_id: current_user.id)


    @show_username = @game_message.user.username != previous_message_username

    message_script_template = render_to_string template: 'game_messages/create.js.erb', layout: false

    ActionCable.server.broadcast("game_message:#{game_message_params[:game_id]}", script: message_script_template)

    head :ok
  end

  private

  def game_message_params
    params.require(:game_message).permit(:body, :game_id, :meta)
  end
end
