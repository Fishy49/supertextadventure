# frozen_string_literal: true

# QA Test World — used by the debug game mode route (/dev/game).
# Full-featured world for manual QA and system tests.

require_relative "../../test/support/qa_world_data"

World.find_or_create_by!(name: "QA Test World") do |world|
  world.description = "A full-featured world for QA / developer testing"
  world.world_data = TestSupport::QaWorldData.data
end
