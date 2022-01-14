# frozen_string_literal: true

class GamesController < ApplicationController
  before_action :set_turbo_frame_id
  before_action :set_game, only: %i[show edit update destroy]

  # GET /games or /games.json
  def index
    @games = Game.all

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "list")
      end
      format.html
    end
  end

  # GET /games/1 or /games/1.json
  def show; end

  # GET /games/new
  def new
    @game = Game.new
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "games/form", locals: { game: @game })
      end
    end
  end

  # GET /games/1/edit
  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "games/form", locals: { game: @game })
      end
      format.html
    end
  end

  # POST /games or /games.json
  def create
    @game = Game.new(game_params)

    respond_to do |format|
      if @game.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@turbo_frame_id, template: "games/show")
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /games/1 or /games/1.json
  def update
    respond_to do |format|
      if @game.update(game_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@turbo_frame_id, template: "games/show")
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /games/1 or /games/1.json
  def destroy
    @game.destroy

    respond_to do |format|
      format.html { redirect_to games_url, notice: "Game was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_game
    @game = Game.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def game_params
    params.require(:game).permit(:uuid, :name, :game_type, :created_by, :status, :opened_at, :closed_at,
                                 :is_friends_only, :max_players)
  end

  def set_turbo_frame_id
    @turbo_frame_id = params[:turbo_frame_id].presence&.to_sym || :sidebar
  end
end
