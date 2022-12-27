# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden }
      format.html { redirect_to root_path, notice: exception.message }
    end
  end

  before_action :check_for_setup

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

  private

    def check_for_setup
      return if User.where(is_owner: true).any?

      redirect_to setup_path
    end
end
