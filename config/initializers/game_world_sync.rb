# frozen_string_literal: true

# Scan games/ directory on boot and create World records for any
# JSON files whose meta.name doesn't already exist in the database.

Rails.application.config.after_initialize do
  # Skip entirely when no database is reachable (asset precompile, image builds).
  begin
    next unless ActiveRecord::Base.connection_pool.with_connection { |conn| conn.table_exists?("worlds") }
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    next
  end

  games_dir = Rails.root.join("games")
  next unless games_dir.exist?

  Dir.glob(games_dir.join("*.json")).each do |file_path|
    data = JSON.parse(File.read(file_path))
    name = data.dig("meta", "name")

    unless name
      Rails.logger.warn("game_world_sync: Skipping #{File.basename(file_path)} — missing meta.name")
      next
    end

    World.find_or_create_by!(name: name) do |world|
      world.description = data.dig("meta", "description") || ""
      world.world_data = data
      Rails.logger.info("game_world_sync: Created world '#{name}' from #{File.basename(file_path)}")
    end
  rescue JSON::ParserError => e
    Rails.logger.warn("game_world_sync: Skipping #{File.basename(file_path)} — #{e.message}")
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info("game_world_sync: World '#{name}' already created by another process, skipping")
  end
end
