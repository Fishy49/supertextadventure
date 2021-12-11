# frozen_string_literal: true

class GameMessagesController < ApplicationController
  before_action :set_game, except: %i[index destroy]

  # GET /games or /games.json
  def index; end

  # GET /games/1 or /games/1.json
  def show; end

  # GET /games/new
  def new
    @game_message = @game.game_message.new(user_id: current_user.id)
  end

  # GET /games/1/edit
  def edit; end

  # POST /games or /games.json
  def create
    @game.game_messages << GameMessage.new(game_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to messages_url }
    end
  end

  # PATCH/PUT /games/1 or /games/1.json
  def update
    respond_to do |format|
      if @game.update(game_params)
        format.html { redirect_to @game, notice: "Game was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /games/1 or /games/1.json
  def destroy
    @game.destroy
    respond_to do |format|
      format.html { redirect_to games_url, notice: "Game was successfully destroyed." }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_game
    @game = Game.find(params[:game_id])
  end

  # Only allow a list of trusted parameters through.
  def game_params
    params.require(:game_message).permit(:user_id, :game_id, :game_event_id, :content)
  end
end
