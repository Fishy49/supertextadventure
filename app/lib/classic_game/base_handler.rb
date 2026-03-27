# frozen_string_literal: true

module ClassicGame
  class BaseHandler
    attr_reader :game, :user_id

    def initialize(game:, user_id:)
      @game = game
      @user_id = user_id
    end

    delegate :world_snapshot, to: :game

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
      # Only returns items that are accessible (in room, inventory, or open containers)
      def find_item(name_or_id)
        return [nil, nil] if name_or_id.blank?

        items = world_snapshot["items"] || {}

        # Build list of accessible item IDs
        accessible_item_ids = []

        # Items in room
        accessible_item_ids += current_room_state["items"] || []

        # Items in inventory
        accessible_item_ids += player_state["inventory"] || []

        # Items in open containers (in room or inventory)
        accessible_item_ids.dup.each do |potential_container_id|
          accessible_item_ids += get_all_items_in_container(potential_container_id)
        end

        # Try exact match first among accessible items
        return [name_or_id, items[name_or_id]] if accessible_item_ids.include?(name_or_id) && items[name_or_id]

        # Try fuzzy match by keywords among accessible items
        accessible_item_ids.each do |item_id|
          item_def = items[item_id]
          next unless item_def

          keywords = item_def["keywords"] || []
          if keywords.any? do |kw|
            kw.downcase.include?(name_or_id.downcase) || name_or_id.downcase.include?(kw.downcase)
          end
            return [item_id, item_def]
          end
          return [item_id, item_def] if item_def["name"]&.downcase&.include?(name_or_id.downcase)
        end

        [nil, nil]
      end

      # Get all items inside a container recursively
      def get_all_items_in_container(container_id)
        container_def = world_snapshot.dig("items", container_id)
        return [] unless container_def&.dig("is_container")
        return [] unless game.container_open?(container_id)

        result = []
        contents = game.container_contents(container_id)

        contents.each do |item_id|
          result << item_id
          # Recursively get items from nested containers
          result += get_all_items_in_container(item_id)
        end

        result
      end

      # Get NPC definition by ID or fuzzy match
      def find_npc(name_or_id)
        return [nil, nil] if name_or_id.blank?

        npcs = world_snapshot["npcs"] || {}

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
      def item?(item_id)
        player_state["inventory"]&.include?(item_id)
      end

      # Check if item is in current room (including in open containers)
      def item_in_room?(item_id)
        # Direct check
        return true if current_room_state["items"]&.include?(item_id)

        # Check in open containers in the room
        room_items = current_room_state["items"] || []
        room_items.each do |room_item_id|
          return true if item_in_container?(item_id, room_item_id)
        end

        false
      end

      # Check if item is in an open container (recursively)
      def item_in_container?(item_id, container_id)
        container_def = world_snapshot.dig("items", container_id)
        return false unless container_def&.dig("is_container")
        return false unless game.container_open?(container_id)

        contents = game.container_contents(container_id)
        return true if contents.include?(item_id)

        # Recursively check nested containers
        contents.each do |nested_item_id|
          return true if item_in_container?(item_id, nested_item_id)
        end

        false
      end

      # Check if NPC is in current room
      def npc_in_room?(npc_id)
        current_room_state["npcs"]&.include?(npc_id)
      end

      # Get creature definition by ID or fuzzy match
      def find_creature(name_or_id)
        return [nil, nil] if name_or_id.blank?

        creatures = world_snapshot["creatures"] || {}

        # Try exact match first
        return [name_or_id, creatures[name_or_id]] if creatures[name_or_id]

        # Try fuzzy match by keywords
        creatures.each do |creature_id, creature_def|
          keywords = creature_def["keywords"] || []
          return [creature_id, creature_def] if keywords.any? do |kw|
            kw.downcase.include?(name_or_id.downcase) || name_or_id.downcase.include?(kw.downcase)
          end
          return [creature_id, creature_def] if creature_def["name"]&.downcase&.include?(name_or_id.downcase)
        end

        [nil, nil]
      end

      # Check if creature is in current room
      def creature_in_room?(creature_id)
        current_room_state["creatures"]&.include?(creature_id)
      end

      # Check if player is in active combat
      def in_combat?
        player_state.dig("combat", "active") == true
      end

      # Check if in combat with specific creature
      def in_combat_with?(creature_id)
        in_combat? && player_state.dig("combat", "creature_id") == creature_id
      end

      # Get total weapon damage from inventory
      def get_weapon_damage(inventory)
        max_damage = 0
        inventory.each do |item_id|
          item_def = world_snapshot.dig("items", item_id)
          next unless item_def

          weapon_damage = item_def["weapon_damage"] || 0
          max_damage = weapon_damage if weapon_damage > max_damage
        end
        max_damage
      end

      # Get total defense bonus from armor/shields
      def get_defense_bonus(inventory)
        total_defense = 0
        inventory.each do |item_id|
          item_def = world_snapshot.dig("items", item_id)
          next unless item_def

          defense_bonus = item_def["defense_bonus"] || 0
          total_defense += defense_bonus
        end
        total_defense
      end

      # Check if a dice roll is pending
      def pending_roll?
        player_state["pending_roll"].present?
      end

      # Execute directives from a dice roll branch (on_success or on_failure)
      def execute_roll_directives(branch, room_id)
        game.set_flag(branch["sets_flag"], true) if branch["sets_flag"]

        if branch["unlocks_dialogue"]
          topic = branch["unlocks_dialogue"]["topic"]
          game.set_flag("dialogue_unlocked_#{topic}", true)
        end

        return unless branch["unlocks_exit"]

        direction = branch["unlocks_exit"]["direction"]
        exit_room = branch["unlocks_exit"]["room"] || room_id
        game.unlock_exit(exit_room, direction)
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
