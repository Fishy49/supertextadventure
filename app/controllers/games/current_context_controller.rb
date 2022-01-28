# frozen_string_literal: true

module Games
  class CurrentContextController < ApplicationController
    before_action :authorize!
    before_action :set_game

    def edit
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(:context, template: "games/current_context/edit")
        end
        format.html
      end
    end

    def update
      respond_to do |format|
        if @game.update(current_context_params)
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(:context, partial: "games/current_context",
                                                                locals: { game: @game })
          end
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @game.errors, status: :unprocessable_entity }
        end
      end
    end

    private

      def set_game
        @game = Game.where(id: params[:game_id]).or(Game.where(uuid: params[:game_id])).first!
      end

      def current_context_params
        params.require(:game).permit(:current_context, :is_current_context_ascii)
      end
  end
end
