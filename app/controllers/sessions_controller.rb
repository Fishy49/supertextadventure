# frozen_string_literal: true

class SessionsController < ApplicationController
  def new; end

  def create
    user = User.find_by(username: params[:username])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_url, notice: t(:login_successful)
    else
      redirect_to root_url, notice: t(:invalid_login)
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, notice: t(:logged_out)
  end
end
