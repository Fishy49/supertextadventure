# frozen_string_literal: true

module ClassicGame
  class BaseHandler
    attr_reader :game, :user_id

    def initialize(game:, user_id:)
      @game = game
      @user_id = user_id
    end

    def world_snapshot
      game.world_snapshot
    end

    def handle(command)
      raise NotImplementedError, "Subclasses must implement #handle"
    end

    protected

    # Get current player state
    def player_state
      @player_state ||= game.player_state(user_id)
    end

    # Update player state
    def update_player_state(new_state)
      game.update_player_state(user_id, new_state)
      @player_state = new_state
    end

    # Get current room definition from world snapshot
    def current_room_def
      world_snapshot.dig("rooms", player_state["current_room"])
    end

    # Get current room state (items/npcs present)
    def current_room_state
      @current_room_state ||= game.room_state(player_state["current_room"])
    end

    # Update room state
    def update_room_state(room_id, new_state)
      game.update_room_state(room_id, new_state)
      @current_room_state = new_state if room_id == player_state["current_room"]
    end

    # Get item definition by ID or fuzzy match
    def find_item(name_or_id)
      items = world_snapshot.dig("items") || {}

      # Try exact match first
      return [name_or_id, items[name_or_id]] if items[name_or_id]

      # Try fuzzy match by keywords
      items.each do |item_id, item_def|
        keywords = item_def["keywords"] || []
        return [item_id, item_def] if keywords.any? { |kw| kw.include?(name_or_id) || name_or_id.include?(kw) }
        return [item_id, item_def] if item_def["name"]&.downcase&.include?(name_or_id)
      end

      [nil, nil]
    end

    # Get NPC definition by ID or fuzzy match
    def find_npc(name_or_id)
      npcs = world_snapshot.dig("npcs") || {}

      # Try exact match first
      return [name_or_id, npcs[name_or_id]] if npcs[name_or_id]

      # Try fuzzy match by keywords
      npcs.each do |npc_id, npc_def|
        keywords = npc_def["keywords"] || []
        return [npc_id, npc_def] if keywords.any? { |kw| kw.include?(name_or_id) || name_or_id.include?(kw) }
        return [npc_id, npc_def] if npc_def["name"]&.downcase&.include?(name_or_id)
      end

      [nil, nil]
    end

    # Check if item is in player's inventory
    def has_item?(item_id)
      player_state["inventory"]&.include?(item_id)
    end

    # Check if item is in current room
    def item_in_room?(item_id)
      current_room_state["items"]&.include?(item_id)
    end

    # Check if NPC is in current room
    def npc_in_room?(npc_id)
      current_room_state["npcs"]&.include?(npc_id)
    end

    # Success response
    def success(message, state_changes: {})
      {
        success: true,
        response: message,
        state_changes: state_changes
      }
    end

    # Failure response
    def failure(message)
      {
        success: false,
        response: message,
        state_changes: {}
      }
    end
  end
end
