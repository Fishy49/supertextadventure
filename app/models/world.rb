# frozen_string_literal: true

class World < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :world_data, presence: true

  # Set default structure for world_data
  after_initialize :set_default_world_data, if: :new_record?
  after_save :dump_to_file, if: :sync_enabled?

  attr_accessor :skip_file_dump

  def rooms
    world_data["rooms"] || {}
  end

  def items
    world_data["items"] || {}
  end

  def npcs
    world_data["npcs"] || {}
  end

  def creatures
    world_data["creatures"] || {}
  end

  def starting_room
    world_data.dig("meta", "starting_room") || rooms.keys.first
  end

  private

    def set_default_world_data
      self.world_data ||= {
        "meta" => {
          "starting_room" => "start",
          "version" => "1.0"
        },
        "rooms" => {},
        "items" => {},
        "npcs" => {},
        "creatures" => {}
      }
    end

    def sync_enabled?
      ENV["ENABLE_WORLD_SYNC"] == "true" && !skip_file_dump
    end

    def dump_to_file
      sync_dir = Rails.root.join("tmp/worlds")
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
      File.write(file_path, JSON.pretty_generate(world_data))

      # Show diff if old data existed
      if old_data
        changes = JsonDiff.diff(old_data, world_data)
        if changes.any?
          SYNC_LOGGER.info ""
          SYNC_LOGGER.info "World ##{id} (#{name}) changed:"
          SYNC_LOGGER.info JsonDiff.format_changes(changes, world_data)
          SYNC_LOGGER.info ""
        end
      else
        SYNC_LOGGER.info "Dumped World ##{id} (#{name}) to #{file_path}"
      end
    rescue StandardError => e
      SYNC_LOGGER.error "Failed to dump World ##{id}: #{e.message}"
    end
end
