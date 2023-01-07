# frozen_string_literal: true

class UsersController < ApplicationController
  load_and_authorize_resource
  skip_authorize_resource only: %i[index activate show edit update destroy]

  before_action :set_user, only: %i[show edit update destroy]

  # GET /users or /users.json
  def index
    @users = User.all
  end

  # GET /users/activate
  def activate
    @token = SetupToken.active.find_by(uuid: params[:code])

    respond_to do |format|
      if @token.blank?
        format.html { redirect_to root_url, notice: t(:token_link_invalid) }
      else
        @user = User.new
        format.html { render :new }
      end
    end
  end

  # GET /users/1 or /users/1.json
  def show; end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit; end

  # POST /users or /users.json
  def create
    @user = User.new(user_params)
    token = SetupToken.active.find_by(uuid: params[:code])

    respond_to do |format|
      if token.blank?
        format.html { redirect_to root_url, notice: t(:token_link_invalid) }
      elsif @user.save
        token.update(user_id: @user.id)
        format.html { redirect_to root_url, notice: "#{@user.username} is now registered for adventure." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_url(@user), notice: t(:user_updated) }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url, notice: t(:user_destroyed) }
      format.json { head :no_content }
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit(:username, :password, :password_confirmation, :code)
    end
end
