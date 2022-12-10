# frozen_string_literal: true

class MessagesController < ApplicationController
  def index
    @game = Game.find_by uuid: params[:game_id]
    @pagy, @messages = pagy(Message.for_game(@game), items: 10)
  end

  def create
    message = Message.create(message_params)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(:messages, partial: "messages/message",
                                                            locals: { message: message })
      end
    end
  end

  private

    def message_params
      params.require(:message).permit(:game_id, :game_user_id, :content)
    end
end
