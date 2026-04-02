# frozen_string_literal: true

class SessionsController < ApplicationController
  layout "portal"

  skip_before_action :require_login

  def new; end

  def create
    user = User.find_by(username: params[:username])
    if user&.authenticate(params[:password])
      reset_session
      session[:user_id] = user.id
      OnboardingService.create_for(user)
      redirect_to tavern_url, notice: t(:login_successful)
    else
      redirect_to root_url, notice: t(:invalid_login)
    end
  end

  def destroy
    reset_session
    redirect_to root_url, notice: t(:logged_out)
  end
end
