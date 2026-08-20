# frozen_string_literal: true

# Custom logger for WorldSync output. The file logger only exists when the
# world-sync dev feature is enabled - log/ may not exist in production images.
SYNC_LOGGER =
  if ENV["ENABLE_WORLD_SYNC"] == "true"
    Logger.new(Rails.root.join("log/world_sync.log"))
  else
    Logger.new(File::NULL)
  end
SYNC_LOGGER.formatter = proc do |_severity, datetime, _progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}\n"
end
