# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :set_game
  before_action :require_game_participant

  def index
    @pagy, @messages = pagy(Message.for_game(@game), items: 10)
  end

  def create
    Message.create(message_params)

    respond_to do |format|
      format.turbo_stream { head :ok }
    end
  end

  private

    def set_game
      game_id = params[:game_id] || params.dig(:message, :game_id)
      @game = Game.where(id: game_id).or(Game.where(uuid: game_id)).first!
    end

    def require_game_participant
      return if @game.host?(current_user)
      return if @game.game_users.exists?(user: current_user)

      head :forbidden
    end

    def message_params
      params.expect(message: %i[game_id game_user_id content])
    end
end
