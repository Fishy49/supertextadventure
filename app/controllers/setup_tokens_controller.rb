# frozen_string_literal: true

class SetupTokensController < ApplicationController
  authorize_resource

  def index
    @tokens = SetupToken.all
  end

  def create
    token = SetupToken.create!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(:setup_tokens, partial: "setup_tokens/setup_token",
                                                                locals: { token: token })
      end
    end
  end

  def destroy
    token = SetupToken.find(params[:id])
    token.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(token)
      end
    end
  end
end
