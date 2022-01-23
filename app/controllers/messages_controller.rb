# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    Message.create(message_params)

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

    def message_params
      params.require(:message).permit(:game_id, :user_id, :content)
    end
end
