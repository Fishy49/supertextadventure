# frozen_string_literal: true

class SetupController < ApplicationController
  skip_before_action :check_for_setup, only: %w[index save]

  def index; end

  def save
    user = User.new(setup_params.merge({ is_owner: true }))

    respond_to do |format|
      if user.save
        session[:user_id] = user.id
        format.html { redirect_to setup_tokens_path, notice: "#{user.username} is now the owner!" }
      else
        format.html { render :index, notice: "Error Setting Up Owner" }
      end
    end
  end

  private

    def setup_params
      params.require(:setup).permit(:username, :password, :password_confirmation)
    end
end
