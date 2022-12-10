# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend
  
  helper_method :current_user
  helper_method :logged_in?

  def current_user
    if session[:user_id]
      @current_user ||= User.find(session[:user_id])
    else
      @current_user = nil
    end
  end

  def logged_in?
    current_user.present?
  end

  def authorize!
    redirect_to root_url, notice: "Away with ye! The tavern is for adventurers only!" unless logged_in?
  end
end
