# frozen_string_literal: true

module ClassicGame
  # Plays a world through the real engine with no database: one player, one
  # in-memory game. Every command is recorded in #transcript and #state
  # summarizes where things stand, so a script (or an agent) can check that a
  # puzzle actually works.
  #
  #   play = ClassicGame::Playthrough.new(world_data, seed: 7)
  #   play.intro          # => "=== Cellar ===\n..."
  #   play.run("take key") # => #<Turn command="take key" response="Taken." success=true>
  #   play.state          # => { "room" => "cellar", "inventory" => ["key"], ... }
  class Playthrough
    Player = Struct.new(:id)
    Turn = Struct.new(:command, :response, :success, keyword_init: true)

    attr_reader :game, :transcript, :seed

    # seed makes dice rolls, flee attempts, and damage variance repeatable.
    def initialize(world_data, seed: nil)
      world = world_data.is_a?(String) ? JSON.parse(world_data) : world_data
      @seed = seed
      @game = HeadlessGame.new(world_data: world.deep_dup.deep_stringify_keys)
      @player = Player.new(1)
      @transcript = []
      srand(seed) if seed
    end

    def intro
      StartingRoom.describe(game)
    end

    def run(command_text)
      result = Engine.execute(game: game, user: @player, command_text: command_text.to_s)
      turn = Turn.new(command: command_text, response: result[:response].to_s, success: result[:success] == true)
      transcript << turn
      turn
    end

    def player_state
      game.player_state(@player.id)
    end

    def last_response
      transcript.last&.response.to_s
    end

    def state
      ps = player_state
      {
        "room" => ps["current_room"],
        "inventory" => Array(ps["inventory"]),
        "health" => ps["health"],
        "max_health" => ps["max_health"],
        "flags" => game.game_state["global_flags"] || {},
        "turns" => game.turn_count,
        "visited" => Array(ps["visited_rooms"]),
        "in_combat" => ps.dig("combat", "active") == true,
        "pending_roll" => ps["pending_roll"].present?,
        "dead" => ps["pending_restart"] == true
      }
    end
  end
end
