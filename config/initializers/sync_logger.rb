# frozen_string_literal: true

# Custom logger for WorldSync output
SYNC_LOGGER = Logger.new(Rails.root.join("log", "world_sync.log"))
SYNC_LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}\n"
end
