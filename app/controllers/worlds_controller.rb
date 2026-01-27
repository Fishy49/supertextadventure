# frozen_string_literal: true

class WorldsController < ApplicationController
  before_action :set_world, only: %i[show edit update destroy preview entity_form create_entity update_entity delete_entity]

  def index
    @worlds = World.all.order(created_at: :desc)
  end

  def show
    redirect_to edit_world_path(@world)
  end

  def new
    @world = World.new
  end

  def create
    @world = World.new(world_params)

    if @world.save
      redirect_to edit_world_path(@world), notice: "World created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render layout: "world_editor"
  end

  def update
    if @world.update(world_params)
      respond_to do |format|
        format.html { redirect_to edit_world_path(@world), notice: "World updated successfully" }
        format.json { render json: { success: true, message: "World updated successfully" } }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @world.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @world.destroy
    redirect_to worlds_path, notice: "World deleted successfully"
  end

  # Render preview from JSON (for live updates as user edits)
  def preview
    world_data = JSON.parse(params[:world_data])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "world-preview",
          partial: "worlds/preview",
          locals: { world_data: world_data, world: @world }
        )
      end
    end
  end

  # Render entity form in modal
  def entity_form
    entity_type = params[:type]
    entity_id = params[:entity_id]

    # Meta is special - it's not a collection
    if entity_type == "meta"
      entity_data = @world.world_data["meta"] || {}
    else
      entity_data = entity_id.present? ? @world.world_data.dig(pluralize(entity_type), entity_id) : {}
    end

    render partial: "worlds/entity_modal",
           locals: {
             entity_type: entity_type,
             entity_id: entity_id,
             entity_data: entity_data || {},
             world: @world
           },
           layout: false
  end

  # Create a new entity
  def create_entity
    entity_type = params[:entity_type]
    entity_data = parse_entity_params(entity_type)

    # Add to world_data
    world_data = @world.world_data.deep_dup

    if entity_type == "meta"
      # Meta is special - it's not a collection
      world_data["meta"] = entity_data
    else
      # Generate ID from name for regular entities
      entity_id = entity_data["name"].downcase.gsub(/\s+/, "_")
      plural_type = pluralize(entity_type)
      world_data[plural_type] ||= {}
      world_data[plural_type][entity_id] = entity_data
    end

    if @world.update(world_data: world_data)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("world-preview", partial: "worlds/preview", locals: { world_data: world_data, world: @world }),
            turbo_stream.update("entity-modal", ""),
            turbo_stream.update("editor-json-update", JSON.pretty_generate(world_data))
          ]
        end
      end
    end
  end

  # Update an existing entity
  def update_entity
    entity_type = params[:entity_type]
    entity_id = params[:entity_id]
    entity_data = parse_entity_params(entity_type)

    # Update in world_data
    world_data = @world.world_data.deep_dup

    if entity_type == "meta"
      # Meta is special - update the meta object directly
      world_data["meta"] = entity_data
    else
      plural_type = pluralize(entity_type)
      world_data[plural_type][entity_id] = entity_data
    end

    if @world.update(world_data: world_data)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("world-preview", partial: "worlds/preview", locals: { world_data: world_data, world: @world }),
            turbo_stream.update("entity-modal", ""),
            turbo_stream.update("editor-json-update", JSON.pretty_generate(world_data))
          ]
        end
      end
    end
  end

  # Delete an entity
  def delete_entity
    entity_type = params[:entity_type]
    entity_id = params[:entity_id]

    # Remove from world_data
    world_data = @world.world_data.deep_dup
    plural_type = pluralize(entity_type)
    world_data[plural_type]&.delete(entity_id)

    if @world.update(world_data: world_data)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("world-preview", partial: "worlds/preview", locals: { world_data: world_data, world: @world }),
            turbo_stream.update("editor-json-update", JSON.pretty_generate(world_data))
          ]
        end
      end
    end
  end

  private

  def set_world
    @world = World.find(params[:id])
  end

  def pluralize(entity_type)
    case entity_type
    when "room" then "rooms"
    when "item" then "items"
    when "npc" then "npcs"
    when "creature" then "creatures"
    when "meta" then "meta"
    else "#{entity_type}s"
    end
  end

  def parse_entity_params(entity_type)
    case entity_type
    when "room"
      {
        "name" => params[:name],
        "description" => params[:description],
        "exits" => parse_exits,
        "items" => parse_array(params[:items]),
        "npcs" => parse_array(params[:npcs])
      }.compact
    when "item"
      {
        "name" => params[:name],
        "description" => params[:description],
        "keywords" => parse_array(params[:keywords]),
        "takeable" => params[:takeable] == "1"
      }.compact
    when "npc"
      {
        "name" => params[:name],
        "description" => params[:description],
        "dialogue" => parse_dialogue,
        "accepts_item" => params[:accepts_item].presence,
        "gives_item" => params[:gives_item].presence
      }.compact
    when "creature"
      {
        "name" => params[:name],
        "description" => params[:description],
        "health" => params[:health].to_i,
        "hostile" => params[:hostile] == "1"
      }.compact
    when "meta"
      {
        "starting_room" => params[:starting_room],
        "version" => params[:version],
        "author" => params[:author].presence
      }.compact
    end
  end

  def parse_exits
    return nil unless params[:exit_data].present?

    exits = {}
    params[:exit_data].each do |index, exit_info|
      direction = exit_info[:direction]
      destination = exit_info[:destination]

      next unless direction.present? && destination.present?

      # Check if this is a simple exit or complex
      show_advanced = exit_info[:show_advanced] == "1"

      if !show_advanced
        # Simple string exit
        exits[direction] = destination
      else
        # Complex exit object
        exit_obj = { "to" => destination }

        # Determine unlock type and add appropriate fields
        unlock_type = exit_info[:unlock_type]

        case unlock_type
        when "requires"
          exit_obj["requires"] = exit_info[:requires] if exit_info[:requires].present?
        when "requires_flag"
          exit_obj["requires_flag"] = exit_info[:requires_flag] if exit_info[:requires_flag].present?
        when "use_item"
          exit_obj["use_item"] = exit_info[:use_item] if exit_info[:use_item].present?
          exit_obj["permanently_unlock"] = true if exit_info[:permanently_unlock] == "1"
          exit_obj["consume_item"] = true if exit_info[:consume_item] == "1"
          exit_obj["on_unlock"] = exit_info[:on_unlock] if exit_info[:on_unlock].present?
        end

        # Add hidden status
        exit_obj["hidden"] = true if exit_info[:hidden] == "1"

        # Add messages
        exit_obj["locked_msg"] = exit_info[:locked_msg] if exit_info[:locked_msg].present?
        exit_obj["unlocked_msg"] = exit_info[:unlocked_msg] if exit_info[:unlocked_msg].present?
        exit_obj["reveal_msg"] = exit_info[:reveal_msg] if exit_info[:reveal_msg].present?

        # Add flag setting
        exit_obj["sets_flag"] = exit_info[:sets_flag] if exit_info[:sets_flag].present?

        exits[direction] = exit_obj
      end
    end

    exits.present? ? exits : nil
  end

  def parse_dialogue
    return nil unless params[:dialogue_keys].present?

    dialogue = {}
    params[:dialogue_keys].each_with_index do |key, index|
      text = params[:dialogue_texts][index]
      dialogue[key] = text if key.present? && text.present?
    end
    dialogue.present? ? dialogue : nil
  end

  def parse_array(string)
    return nil if string.blank?
    string.split(",").map(&:strip).reject(&:blank?)
  end

  def world_params
    permitted = params.require(:world).permit(:name, :description, :world_data)

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
