# frozen_string_literal: true

class World < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :world_data, presence: true
  validate :world_data_contract

  # Set default structure for world_data
  after_initialize :set_default_world_data, if: :new_record?
  before_validation :fill_meta_defaults
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

  # Errors from the shared world contract: [{ code:, path:, message: }]
  def contract_errors
    ClassicGame::WorldValidator.new(world_data).errors
  end

  private

    def set_default_world_data
      self.world_data ||= {
        "meta" => {
          "name" => name,
          "description" => description,
          "starting_room" => "start",
          "version" => "1.0"
        },
        "rooms" => {
          "start" => {
            "name" => "Starting Room",
            "description" => "You are standing in an empty room. Describe it, then add some exits.",
            "exits" => {},
            "items" => [],
            "npcs" => [],
            "creatures" => []
          }
        },
        "items" => {},
        "npcs" => {},
        "creatures" => {}
      }
    end

    # meta.name and meta.description are required by the contract; fill them
    # from the record when the author has not written them yet.
    def fill_meta_defaults
      return unless world_data.is_a?(Hash)

      meta = (world_data["meta"] ||= {})
      return unless meta.is_a?(Hash)

      meta["name"] = name if meta["name"].blank? && name.present?
      meta["description"] = description if meta["description"].blank? && description.present?
    end

    def world_data_contract
      return if world_data.blank?

      contract_errors.each { |e| errors.add(:world_data, e[:message]) }
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
