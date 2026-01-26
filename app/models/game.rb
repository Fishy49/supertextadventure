# frozen_string_literal: true

class Game < ApplicationRecord

  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    dependent: :destroy,
                    inverse_of: :hosted_games,
                    optional: true

  has_many :game_users, inverse_of: :game, dependent: :destroy
  has_many :users, through: :game_users

  has_many :chapters, inverse_of: :game, dependent: :destroy

  has_many :messages, inverse_of: :game, dependent: :destroy

  belongs_to :world, optional: true

  enum :game_type, {
    chat: "chat",
    chat_ai: "chat_ai",
    classic: "classic",
    classic_ai: "classic_ai"
  }, default: "chat_ai"

  scope :joinable_by_user, ->(user) { where(status: :open).where.not(created_by: user.id) }

  before_create :set_uuid

  after_save :broadcast_context, if: :saved_change_to_current_context?
  after_save :dump_game_state_to_file, if: :should_dump_game_state?

  after_create_commit :setup_ai, if: :chat_ai?
  after_create_commit :setup_classic_game, if: :classic?

  validates :created_by, presence: true

  attr_accessor :skip_game_state_dump

  def complete_chapters
    chapters.order(:id).where.not(last_message_id: nil)
  end

  def current_chapter
    chapters.where(last_message_id: nil).last
  end

  def current_messages
    messages.where("id > ?", current_chapter&.first_message_id || 0)
  end

  def ai_config
    @ai_config ||= case game_type.to_sym
                   when :chat_ai
                     AiConfigs::ChatAiConfig.new(self)
                   else
                     raise "Unknown game type: #{game_type}"
                   end
  end

  def messages_for_ai
    ai_config.messages_for_ai
  end

  def current_token_count
    # Approximate token count: ~4 characters per token for GPT models
    text = messages_for_ai.map { |m| m[:content] }.join
    (text.length / 4.0).ceil
  end

  def game_user(user)
    game_users.find_by(user_id: user.id)
  end

  def host?(user)
    return false if chat_ai?

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

  def ai_game?
    [:chat_ai, :classic_ai].include?(game_type)
  end

  # Classic game state methods
  def world_snapshot
    game_state.dig("world_snapshot") || {}
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

  private

    def initialize_player_state(user_id)
      starting_room = world_snapshot.dig("meta", "starting_room") || world_snapshot.dig("rooms")&.keys&.first

      {
        "current_room" => starting_room,
        "inventory" => [],
        "health" => 100,
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

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
    end

    def broadcast_context
      broadcast_replace_to(self, :state, target: :context_content, partial: "/games/current_context",
                                         locals: { game: self })
    end

    def setup_ai
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      chat_log = messages_for_ai
      chat_log << { role: "user",
                    content: <<-INSTRUCTION
                    Please create a very brief description of the game world. No players have joined yet.
                    Also describe the opening scene the players will once they join the game.
                    INSTRUCTION
                  }
      response = client.responses.create(model: ai_config.model_name, input: chat_log)
      ai_response = response.output_text

      message = Message.create(game_id: id, content: ai_response)

      Chapter.create(game_id: id, number: 1, first_message_id: message.id)
    end

    def setup_classic_game
      # Use the selected world, or fall back to the first available
      selected_world = world || World.first

      unless selected_world
        raise "No worlds available! Please create a world first."
      end

      # Update game to use this world if not already set
      update!(world: selected_world) unless world

      # Snapshot the world data into game_state to isolate from future world changes
      update!(game_state: {
        "world_snapshot" => selected_world.world_data.deep_dup,
        "player_states" => {},
        "room_states" => {},
        "global_flags" => {}
      })

      # Generate starting room description
      starting_room_description = generate_starting_room_description

      # Send initial room description (as a host message so it broadcasts)
      Message.create!(
        game: self,
        content: starting_room_description
        # Note: no game_user_id, so it's a "host" message that will broadcast
      )
    end

    def generate_starting_room_description
      starting_room_id = world_snapshot.dig("meta", "starting_room") || world_snapshot.dig("rooms")&.keys&.first
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

      # List exits
      exits = room_def["exits"] || {}
      if exits.any?
        lines << ""
        lines << "Exits: #{exits.keys.map(&:to_s).map(&:upcase).join(', ')}"
      end

      lines << ""
      lines << "Type HELP for available commands."

      lines.join("\n")
    end

    def should_dump_game_state?
      ENV["ENABLE_WORLD_SYNC"] == "true" &&
        !skip_game_state_dump &&
        saved_change_to_game_state? &&
        (classic? || classic_ai?)
    end

    def dump_game_state_to_file
      sync_dir = Rails.root.join("tmp", "games")
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
