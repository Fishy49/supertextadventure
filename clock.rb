# frozen_string_literal: true

require "clockwork"
require_relative "./config/boot"
require_relative "./config/environment"

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every(5.seconds, "presence.cleanup") { PresenceCleanupJob.perform_later }
end
