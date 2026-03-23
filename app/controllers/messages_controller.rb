# frozen_string_literal: true

class MessagesController < ApplicationController
  def index
    @game = Game.find_by uuid: params[:game_id]
    @pagy, @messages = pagy(Message.for_game(@game), items: 10)
  end

  def create
    Message.create(message_params)

    respond_to do |format|
      format.turbo_stream { head :ok }
    end
  end

  private

    def message_params
      params.expect(message: %i[game_id game_user_id content])
    end
end
