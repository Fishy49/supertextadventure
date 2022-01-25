# frozen_string_literal: true

class MessagesController < ApplicationController
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
      params.require(:message).permit(:game_id, :user_id, :content)
    end
end
