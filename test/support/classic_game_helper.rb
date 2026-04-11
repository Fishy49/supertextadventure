# frozen_string_literal: true

# In-memory game double for testing ClassicGame handlers without hitting the database.
# Implements all game state methods used by BaseHandler and its subclasses.
module ClassicGameTestHelper
  class FakeGame
    attr_accessor :game_state, :character_names

    def initialize(world_data:)
      @game_state = {
        "world_snapshot" => world_data,
        "player_states" => {},
        "room_states" => {},
        "global_flags" => {},
        "container_states" => {},
        "unlocked_exits" => {},
        "revealed_exits" => {},
        "turn_count" => 0,
        "npc_movement" => {},
        "turn_state" => { "turn_order" => [], "current_index" => 0 }
      }
      @character_names = {}
    end

    def world_snapshot
      @game_state["world_snapshot"] || {}
    end

    def player_state(user_id)
      @game_state.dig("player_states", user_id.to_s) || initialize_player_state(user_id)
    end

    def update_player_state(user_id, new_state)
      @game_state["player_states"][user_id.to_s] = new_state
    end

    def room_state(room_id)
      @game_state.dig("room_states", room_id.to_s) || initialize_room_state(room_id)
    end

    def update_room_state(room_id, new_state)
      @game_state["room_states"][room_id.to_s] = new_state
    end

    def get_flag(flag_name)
      @game_state.dig("global_flags", flag_name.to_s)
    end

    def set_flag(flag_name, value)
      @game_state["global_flags"] ||= {}
      @game_state["global_flags"][flag_name.to_s] = value
    end

    def exit_unlocked?(room_id, direction)
      @game_state.dig("unlocked_exits", "#{room_id}_#{direction}") || false
    end

    def unlock_exit(room_id, direction)
      @game_state["unlocked_exits"]["#{room_id}_#{direction}"] = true
    end

    def exit_revealed?(room_id, direction)
      @game_state.dig("revealed_exits", "#{room_id}_#{direction}") || false
    end

    def reveal_exit(room_id, direction)
      @game_state["revealed_exits"]["#{room_id}_#{direction}"] = true
    end

    def container_open?(container_id)
      state = @game_state.dig("container_states", container_id.to_s)
      return state["open"] if state

      item_def = world_snapshot.dig("items", container_id.to_s)
      return true unless item_def&.dig("starts_closed")

      false
    end

    def open_container(container_id)
      @game_state["container_states"][container_id.to_s] = { "open" => true }
    end

    def close_container(container_id)
      @game_state["container_states"][container_id.to_s] = { "open" => false }
    end

    def container_contents(container_id)
      original = world_snapshot.dig("items", container_id.to_s, "contents") || []
      removed = @game_state.dig("container_states", container_id.to_s, "removed_items") || []
      original - removed
    end

    def remove_from_container(container_id, item_id)
      @game_state["container_states"][container_id.to_s] ||= {}
      @game_state["container_states"][container_id.to_s]["removed_items"] ||= []
      @game_state["container_states"][container_id.to_s]["removed_items"] << item_id
      @game_state["container_states"][container_id.to_s]["removed_items"].uniq!
    end

    def turn_count
      @game_state["turn_count"] || 0
    end

    def increment_turn_count
      @game_state["turn_count"] = turn_count + 1
    end

    def npc_movement_state(entity_id)
      @game_state.dig("npc_movement", entity_id.to_s) || {}
    end

    def update_npc_movement_state(entity_id, state)
      @game_state["npc_movement"] ||= {}
      @game_state["npc_movement"][entity_id.to_s] = state
    end

    # Turn management methods

    def turn_state
      @game_state["turn_state"] || { "turn_order" => [], "current_index" => 0 }
    end

    def current_turn_user_id
      ts = turn_state
      order = ts["turn_order"] || []
      return nil if order.empty?

      order[ts["current_index"] || 0]
    end

    def advance_turn
      ts = turn_state.dup
      order = ts["turn_order"] || []
      return nil if order.empty?

      count = order.length
      current = ts["current_index"] || 0

      attempts = 0
      loop do
        current = (current + 1) % count
        attempts += 1
        break if attempts >= count

        uid = order[current]
        next_ps = @game_state.dig("player_states", uid.to_s) || {}
        break unless next_ps["waiting_for_combat_end"]
      end

      ts["current_index"] = current
      @game_state["turn_state"] = ts
      order[current]
    end

    def players_in_room(room_id)
      states = @game_state["player_states"] || {}
      states.select { |_uid, state| state["current_room"] == room_id.to_s }
            .map { |uid, state| [uid.to_i, state] }
    end

    def all_player_user_ids
      (@game_state["player_states"] || {}).keys.map(&:to_i)
    end

    def register_player_turn_order(user_id)
      @game_state["turn_state"] ||= { "turn_order" => [], "current_index" => 0 }
      order = @game_state["turn_state"]["turn_order"] ||= []
      order << user_id.to_i unless order.include?(user_id.to_i)
    end

    def character_name_for(user_id)
      @character_names[user_id.to_i] || "Player #{user_id}"
    end

    def starting_hp
      10
    end

    def save!
      # no-op — state is stored in-memory
    end

    def update!(attrs)
      attrs.each do |key, value|
        @game_state = value if key.to_s == "game_state"
      end
    end

    private

      def initialize_player_state(user_id)
        starting_room = world_snapshot.dig("meta", "starting_room") ||
                        world_snapshot["rooms"]&.keys&.first
        state = {
          "current_room" => starting_room,
          "inventory" => [],
          "health" => 10,
          "max_health" => 10,
          "visited_rooms" => [],
          "flags" => {}
        }
        @game_state["player_states"][user_id.to_s] = state
        register_player_turn_order(user_id)
        state
      end

      def initialize_room_state(room_id)
        room_def = world_snapshot.dig("rooms", room_id.to_s)
        return {} unless room_def

        state = {
          "items" => (room_def["items"] || []).dup,
          "npcs" => (room_def["npcs"] || []).dup,
          "creatures" => (room_def["creatures"] || []).dup,
          "modified" => false
        }
        @game_state["room_states"][room_id.to_s] = state
        state
      end
  end

  FakeUser = Struct.new(:id)

  # ─── Engine helper ─────────────────────────────────────────────────────────

  # Route a command through the full Engine (handles pending rolls, aggro checks,
  # restart confirmation, and handler dispatch). Accepts any object that responds
  # to #id — use FakeUser.new(some_id) as the user argument.
  def execute_engine(game, user, command_text)
    ClassicGame::Engine.execute(game: game, user: user, command_text: command_text)
  end

  # Seed the PRNG for deterministic outcomes, then restore the previous seed.
  def with_deterministic_rand(seed = 42)
    old_seed = srand(seed)
    yield
  ensure
    srand(old_seed)
  end

  # ─── Builders ──────────────────────────────────────────────────────────────

  def build_world(rooms: {}, items: {}, npcs: {}, creatures: {}, starting_room: nil)
    {
      "meta" => { "starting_room" => starting_room || rooms.keys.first&.to_s },
      "rooms" => rooms,
      "items" => items,
      "npcs" => npcs,
      "creatures" => creatures
    }
  end

  # Returns a FakeGame pre-populated with optional player/room state overrides.
  def build_game(world_data:, player_id: 1, player_state: nil, room_states: {})
    game = FakeGame.new(world_data: world_data)
    if player_state
      game.game_state["player_states"][player_id.to_s] = player_state
      game.register_player_turn_order(player_id)
    end
    room_states.each { |id, state| game.game_state["room_states"][id.to_s] = state }
    game
  end

  # Returns a FakeGame with multiple players pre-initialized.
  # players: hash of { user_id => player_state_hash }
  # character_names: hash of { user_id => "Name" }
  def build_multiplayer_game(world_data:, players:, character_names: {})
    game = FakeGame.new(world_data: world_data)
    game.character_names = character_names.transform_keys(&:to_i)
    players.each do |user_id, state|
      game.game_state["player_states"][user_id.to_s] = state
      game.register_player_turn_order(user_id)
    end
    game
  end

  # Shorthand to build a player_state hash for use in build_game.
  def player_state_in(room_id, inventory: [], health: 10, max_health: 10, combat: nil,
                      waiting_for_combat_end: false)
    state = {
      "current_room" => room_id.to_s,
      "inventory" => inventory,
      "health" => health,
      "max_health" => max_health,
      "visited_rooms" => [],
      "flags" => {}
    }
    state["combat"] = combat if combat
    state["waiting_for_combat_end"] = true if waiting_for_combat_end
    state
  end
end
