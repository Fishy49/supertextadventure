# frozen_string_literal: true

class WorldsController < ApplicationController
  before_action :set_world, only: %i[show edit update destroy]

  def index
    @worlds = World.order(created_at: :desc)
  end

  def show
    redirect_to edit_world_path(@world)
  end

  def new
    @world = World.new
  end

  def edit
    render layout: "world_editor"
  end

  def create
    @world = World.new(world_params)

    if @world.save
      redirect_to edit_world_path(@world), notice: "World created successfully"
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @world.update(world_params)
      respond_to do |format|
        format.html { redirect_to edit_world_path(@world), notice: "World updated successfully" }
        format.json { render json: { success: true, message: "World updated successfully" } }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_world_path(@world), alert: @world.errors.full_messages.join(", ") }
        format.json do
          render json: { success: false, errors: @world.errors.full_messages }, status: :unprocessable_content
        end
      end
    end
  end

  def destroy
    @world.destroy
    redirect_to worlds_path, notice: "World deleted successfully"
  end

  private

    def set_world
      @world = World.find(params.expect(:id))
    end

    def world_params
      permitted = params.expect(world: %i[name description world_data])

      # Parse world_data if it's a string
      if permitted[:world_data].is_a?(String)
        begin
          permitted[:world_data] = JSON.parse(permitted[:world_data])
        rescue JSON::ParserError => e
          # If parsing fails, let validation handle it
          Rails.logger.error "Failed to parse world_data: #{e.message}"
        end
      end

      permitted
    end
end
