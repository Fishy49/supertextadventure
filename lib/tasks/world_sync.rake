# frozen_string_literal: true

namespace :world do
  desc "Dump all worlds to JSON files in tmp/worlds/"
  task dump_worlds: :environment do
    WorldSync.dump_all_worlds
  end

  desc "Dump all classic game states to JSON files in tmp/games/"
  task dump_games: :environment do
    WorldSync.dump_all_games
  end

  desc "Dump all worlds and game states to JSON files"
  task dump: :environment do
    WorldSync.dump_all_worlds
    WorldSync.dump_all_games
  end
end
