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
  before_action :require_login

  helper_method :current_user
  helper_method :logged_in?

  def current_user
    if session[:user_id]
      @current_user ||= User.find_by(id: session[:user_id])
    else
      @current_user = nil
    end
  end

  def logged_in?
    current_user.present?
  end

  private

    def require_login
      return if logged_in?

      respond_to do |format|
        format.html { redirect_to root_path, notice: t(:login_required) }
        format.json { head :unauthorized }
        format.turbo_stream { head :unauthorized }
      end
    end

    def require_owner
      return if current_user&.is_owner?

      redirect_to root_path, notice: t(:away_with_ye)
    end

    def check_for_setup
      return if User.where(is_owner: true).any?

      redirect_to setup_path
    end
end
