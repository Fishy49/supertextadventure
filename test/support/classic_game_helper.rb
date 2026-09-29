# frozen_string_literal: true

# Helpers for testing ClassicGame handlers without hitting the database.
module ClassicGameTestHelper
  # The engine's in-memory game, promoted from this file into the app so the
  # CLI can play worlds through it. Kept under its old name here.
  FakeGame = ClassicGame::HeadlessGame

  FakeUser = Struct.new(:id)

  # ─── Engine helper ─────────────────────────────────────────────────────────

  # Route a command through the full Engine (handles pending rolls, aggro checks,
  # restart confirmation, and handler dispatch). Accepts any object that responds
  # to #id - use FakeUser.new(some_id) as the user argument.
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
    game.game_state["player_states"][player_id.to_s] = player_state if player_state
    room_states.each { |id, state| game.game_state["room_states"][id.to_s] = state }
    game
  end

  # Shorthand to build a player_state hash for use in build_game.
  def player_state_in(room_id, inventory: [], health: 10, max_health: 10, combat: nil)
    state = {
      "current_room" => room_id.to_s,
      "inventory" => inventory,
      "health" => health,
      "max_health" => max_health,
      "visited_rooms" => [],
      "flags" => {}
    }
    state["combat"] = combat if combat
    state
  end
end
