# frozen_string_literal: true

class WorldSync
  def self.dump_all_worlds
    sync_dir = Rails.root.join("tmp", "worlds")
    FileUtils.mkdir_p(sync_dir)

    World.find_each do |world|
      file_path = sync_dir.join("#{world.id}.json")
      File.write(file_path, JSON.pretty_generate(world.world_data))
      SYNC_LOGGER.info "Dumped World ##{world.id} (#{world.name}) to #{file_path}"
      puts "WorldSync: Dumped World ##{world.id} (#{world.name}) to #{file_path}"
    end
  end

  def self.dump_all_games
    sync_dir = Rails.root.join("tmp", "games")
    FileUtils.mkdir_p(sync_dir)

    Game.where(game_type: [:classic, :classic_ai]).find_each do |game|
      next if game.game_state.blank?

      file_path = sync_dir.join("#{game.id}.json")
      File.write(file_path, JSON.pretty_generate(game.game_state))
      SYNC_LOGGER.info "Dumped Game ##{game.id} (#{game.name}) to #{file_path}"
      puts "WorldSync: Dumped Game ##{game.id} (#{game.name}) to #{file_path}"
    end
  end
end
