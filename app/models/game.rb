# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    inverse_of: :hosted_games,
                    optional: true

  has_many :game_users, inverse_of: :game, dependent: :destroy
  has_many :users, through: :game_users

  has_many :messages, inverse_of: :game, dependent: :destroy

  belongs_to :world, optional: true

  enum :game_type, {
    chat: "chat",
    classic: "classic"
  }, default: "chat"

  scope :joinable_by_user, ->(user) { where(status: :open).where.not(created_by: user.id) }

  before_create :set_uuid

  after_save :broadcast_context, if: :saved_change_to_current_context?
  after_save :dump_game_state_to_file, if: :should_dump_game_state?

  after_create_commit :setup_classic_game, if: :classic?

  validates :created_by, presence: true

  attr_accessor :skip_game_state_dump

  def game_user(user)
    game_users.find_by(user_id: user.id)
  end

  def host?(user)
    created_by == user&.id
  end

  def user_in_game?(user)
    game_users.pluck(:user_id).include?(user.id)
  end

  def can_user_join?(user)
    !user_in_game?(user) && !host?(user) && !max_players?
  end

  def max_players?
    game_users.count == max_players
  end

  def broadcast_updated_player_list
    broadcast_replace_to(self, :players, target: :players, partial: "/games/players",
                                         locals: { game_users: game_users.joined, for_host: false })
  end

  # Classic game state methods
  def world_snapshot
    game_state["world_snapshot"] || {}
  end

  def player_state(user_id)
    game_state.dig("player_states", user_id.to_s) || initialize_player_state(user_id)
  end

  def update_player_state(user_id, new_state)
    self.game_state ||= {}
    self.game_state["player_states"] ||= {}
    self.game_state["player_states"][user_id.to_s] = new_state
    save!
  end

  def room_state(room_id)
    game_state.dig("room_states", room_id.to_s) || initialize_room_state(room_id)
  end

  def update_room_state(room_id, new_state)
    self.game_state ||= {}
    self.game_state["room_states"] ||= {}
    self.game_state["room_states"][room_id.to_s] = new_state
    save!
  end

  def get_flag(flag_name)
    game_state.dig("global_flags", flag_name.to_s)
  end

  def set_flag(flag_name, value)
    self.game_state ||= {}
    self.game_state["global_flags"] ||= {}
    self.game_state["global_flags"][flag_name.to_s] = value
    save!
  end

  def unlock_exit(room_id, direction)
    self.game_state ||= {}
    self.game_state["unlocked_exits"] ||= {}
    exit_key = "#{room_id}_#{direction}"
    self.game_state["unlocked_exits"][exit_key] = true
    save!
  end

  def exit_unlocked?(room_id, direction)
    exit_key = "#{room_id}_#{direction}"
    game_state.dig("unlocked_exits", exit_key) || false
  end

  def reveal_exit(room_id, direction)
    self.game_state ||= {}
    self.game_state["revealed_exits"] ||= {}
    exit_key = "#{room_id}_#{direction}"
    self.game_state["revealed_exits"][exit_key] = true
    save!
  end

  def exit_revealed?(room_id, direction)
    exit_key = "#{room_id}_#{direction}"
    game_state.dig("revealed_exits", exit_key) || false
  end

  # Container state methods
  def container_state(container_id)
    game_state.dig("container_states", container_id.to_s)
  end

  def container_open?(container_id)
    state = container_state(container_id)
    return state["open"] if state

    # If no state exists, check if container starts closed
    item_def = world_snapshot.dig("items", container_id.to_s)
    return true unless item_def&.dig("starts_closed")

    false
  end

  def open_container(container_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] = { "open" => true }
    save!
  end

  def close_container(container_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] = { "open" => false }
    save!
  end

  def container_contents(container_id)
    # Get original contents from world snapshot
    original_contents = world_snapshot.dig("items", container_id.to_s, "contents") || []

    # Get removed items from game state
    removed_items = game_state.dig("container_states", container_id.to_s, "removed_items") || []

    # Return contents minus removed items
    original_contents - removed_items
  end

  def remove_from_container(container_id, item_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] ||= {}
    self.game_state["container_states"][container_id.to_s]["removed_items"] ||= []
    self.game_state["container_states"][container_id.to_s]["removed_items"] << item_id
    self.game_state["container_states"][container_id.to_s]["removed_items"].uniq!
    save!
  end

  # Turn management methods
  def turn_order
    game_state.dig("turn_state", "order") || []
  end

  def current_turn_user_id
    game_state.dig("turn_state", "current_user_id")
  end

  def initialize_turn_order(user_ids)
    self.game_state ||= {}
    self.game_state["turn_state"] = {
      "order" => user_ids.map(&:to_s),
      "current_user_id" => user_ids.first&.to_s,
      "combat_waiting" => []
    }
    save!
  end

  def advance_turn
    ts = game_state["turn_state"]
    return unless ts

    order = ts["order"]
    return if order.empty?

    combat_waiting = ts["combat_waiting"] || []
    current = ts["current_user_id"].to_s
    current_index = order.index(current) || 0

    next_index = (current_index + 1) % order.length
    attempts = 0

    while attempts < order.length
      candidate = order[next_index]
      dead = game_state.dig("player_states", candidate, "pending_restart")
      break unless combat_waiting.include?(candidate) || dead

      next_index = (next_index + 1) % order.length
      attempts += 1
    end

    ts["current_user_id"] = order[next_index]
    save!
  end

  def player_fled_combat(user_id)
    ts = game_state["turn_state"]
    return unless ts

    ts["combat_waiting"] ||= []
    ts["combat_waiting"] << user_id.to_s
    ts["combat_waiting"].uniq!
    advance_turn
  end

  def combat_ended
    ts = game_state["turn_state"]
    return unless ts

    ts["combat_waiting"] = []
    save!
  end

  def players_in_room(room_id)
    (game_state["player_states"] || {}).select do |_uid, state|
      state["current_room"] == room_id.to_s
    end.keys
  end

  def add_to_container(container_id, item_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] ||= {}
    self.game_state["container_states"][container_id.to_s]["removed_items"] ||= []
    self.game_state["container_states"][container_id.to_s]["removed_items"].delete(item_id)
    save!
  end

  private

    def initialize_player_state(_user_id)
      starting_room = world_snapshot.dig("meta", "starting_room") || world_snapshot["rooms"]&.keys&.first

      {
        "current_room" => starting_room,
        "inventory" => [],
        "health" => starting_hp || 10,
        "max_health" => starting_hp || 10,
        "visited_rooms" => [],
        "flags" => {}
      }
    end

    def initialize_room_state(room_id)
      room_def = world_snapshot.dig("rooms", room_id.to_s)
      return {} unless room_def

      {
        "items" => room_def["items"] || [],
        "npcs" => room_def["npcs"] || [],
        "creatures" => room_def["creatures"] || [],
        "modified" => false
      }
    end

    def set_uuid
      self.uuid = SecureRandom.uuid
    end

    def broadcast_context
      broadcast_replace_to(self, :state, target: :context_content, partial: "/games/current_context",
                                         locals: { game: self })
    end

    def setup_classic_game
      # Use the selected world, or fall back to the first available
      selected_world = world || World.first

      raise "No worlds available! Please create a world first." unless selected_world

      # Update game to use this world if not already set
      update!(world: selected_world) unless world

      # Snapshot the world data into game_state to isolate from future world changes
      world_snapshot_data = selected_world.world_data.deep_dup

      # Validate dice roll directives have both branches
      validation_errors = ClassicGame::Engine.validate_world_data(world_snapshot_data)
      raise "Invalid world data: #{validation_errors.join('; ')}" if validation_errors.any?

      update!(game_state: {
                "world_snapshot" => world_snapshot_data,
                "player_states" => {},
                "room_states" => {},
                "global_flags" => {},
                "container_states" => {}
              })

      # Generate starting room description
      starting_room_description = generate_starting_room_description

      # Send initial room description (as a host message so it broadcasts)
      Message.create!(
        game: self,
        content: starting_room_description
        # NOTE: no game_user_id, so it's a "host" message that will broadcast
      )
    end

    def generate_starting_room_description
      starting_room_id = world_snapshot.dig("meta", "starting_room") || world_snapshot["rooms"]&.keys&.first
      room_def = world_snapshot.dig("rooms", starting_room_id)

      return "Error: Starting room not found." unless room_def

      # Initialize room state for starting room
      room_state = room_state(starting_room_id)

      lines = []
      lines << "=== #{room_def['name']} ==="
      lines << ""
      lines << room_def["description"]

      # List visible items
      visible_items = room_state["items"] || []
      if visible_items.any?
        lines << ""
        item_names = visible_items.map { |item_id| world_snapshot.dig("items", item_id, "name") || item_id }
        lines << "You see: #{item_names.join(', ')}"
      end

      # List NPCs
      npcs = room_state["npcs"] || []
      if npcs.any?
        lines << ""
        npc_names = npcs.map { |npc_id| world_snapshot.dig("npcs", npc_id, "name") || npc_id }
        lines << "Present: #{npc_names.join(', ')}"
      end

      # List creatures
      creatures = room_state["creatures"] || []
      if creatures.any?
        lines << ""
        creature_names = creatures.map do |creature_id|
          world_snapshot.dig("creatures", creature_id, "name") || creature_id
        end
        lines << "Creatures: #{creature_names.join(', ')}"
      end

      # List exits
      exits = room_def["exits"] || {}
      if exits.any?
        lines << ""
        lines << "Exits: #{exits.keys.map { |k| k.to_s.upcase }.join(', ')}"
      end

      lines << ""
      lines << "Type HELP for available commands."

      lines.join("\n")
    end

    def should_dump_game_state?
      ENV["ENABLE_WORLD_SYNC"] == "true" &&
        !skip_game_state_dump &&
        saved_change_to_game_state? &&
        classic?
    end

    def dump_game_state_to_file
      sync_dir = Rails.root.join("tmp/games")
      FileUtils.mkdir_p(sync_dir)

      file_path = sync_dir.join("#{id}.json")

      # Read old content if file exists
      old_data = nil
      if File.exist?(file_path)
        begin
          old_data = JSON.parse(File.read(file_path))
        rescue JSON::ParserError
          # Ignore parse errors for old file
        end
      end

      # Write new content
      File.write(file_path, JSON.pretty_generate(game_state))

      # Show diff if old data existed
      if old_data
        changes = JsonDiff.diff(old_data, game_state)
        if changes.any?
          SYNC_LOGGER.info ""
          SYNC_LOGGER.info "Game ##{id} (#{name}) state changed:"
          SYNC_LOGGER.info JsonDiff.format_changes(changes, game_state)
          SYNC_LOGGER.info ""
        end
      else
        SYNC_LOGGER.info "Dumped Game ##{id} (#{name}) state to #{file_path}"
      end
    rescue StandardError => e
      SYNC_LOGGER.error "Failed to dump Game ##{id}: #{e.message}"
    end
end
