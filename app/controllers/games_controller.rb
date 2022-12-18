# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class GamesController < ApplicationController
  before_action :authorize!
  before_action :set_turbo_frame_id
  before_action :set_game, except: %i[index list new create]
  before_action :load_games, only: %i[index list]

  def index; end

  def list
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "list") }
      format.html
    end
  end

  # rubocop:disable Metrics/MethodLength
  def join
    @game.with_lock do
      if @game.can_user_join?(current_user)
        game_user_params = {
          user_id: current_user.id,
          character_name: params[:character_name]
        }

        game_user_params.merge(max_health: @game.starting_hp, current_health: @game.starting_hp) if @game.enable_hp?

        @game_user = @game.game_users.create(game_user_params)
      end

      @game.update(status: :closed) if @game_user.valid? && @game.max_players?
    end

    respond_to do |format|
      if @game_user.valid?
        format.html { redirect_to game_url(id: @game.uuid), notice: t(:ye_joined) }
      else
        format.html { redirect_to tavern_url, notice: t(:join_failed) }
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def lobby
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "lobby")
      end
      format.html
    end
  end

  def show
    if @game.host?(current_user)
      @game.update(host_active_at: DateTime.now)
    else
      @game.game_user(current_user).update(active_at: DateTime.now)
    end

    @pagy, @messages = pagy(Message.for_game(@game), items: 10)
  end

  def new
    @game = Game.new(created_by: current_user.id)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "games/form", locals: { game: @game })
      end
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(@turbo_frame_id, partial: "games/form", locals: { game: @game })
      end
      format.html
    end
  end

  def create
    @game = Game.new(game_params)

    respond_to do |format|
      if @game.save
        format.html { redirect_to game_url(@game) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @game.update(game_params)
        format.turbo_stream { render turbo_stream: turbo_stream.update(@turbo_frame_id, template: "games/show") }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @game.destroy

    respond_to do |format|
      format.html { redirect_to games_url, notice: t(:game_destroyed) }
      format.json { head :no_content }
    end
  end

  private

    def load_games
      @hosted_games = current_user.hosted_games.load_async
      @joined_games = current_user.joined_games.load_async
      @joinable_games = Game.joinable_by_user(current_user).where.not(id: @joined_games.ids).load_async
    end

    def set_game
      @game = Game.where(id: params[:id]).or(Game.where(uuid: params[:id])).first!
    end

    def game_params
      params.require(:game).permit(:uuid, :name, :game_type, :created_by, :status, :opened_at, :closed_at,
                                   :is_friends_only, :max_players, :description, :host_display_name,
                                   :current_context, :is_current_context_ascii, :enable_hp, :starting_hp)
    end

    def set_turbo_frame_id
      @turbo_frame_id = params[:turbo_frame_id].presence&.to_sym || :sidebar
    end
end
# rubocop:enable Metrics/ClassLength
