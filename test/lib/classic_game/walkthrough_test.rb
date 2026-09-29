# frozen_string_literal: true

require "test_helper"

module ClassicGame
  # Every shipped game has a walkthrough next to it (games/<name>.walkthrough.txt)
  # that plays it through the real engine and checks the ending. A world that
  # validates but cannot be finished fails here.
  class WalkthroughTest < ActiveSupport::TestCase
    Rails.root.glob("games/*.json").each do |file|
      script = file.sub_ext(".walkthrough.txt")

      test "#{File.basename(file)} has a walkthrough" do
        assert script.exist?, "add #{script.basename} so the game is known to be finishable"
      end

      next unless script.exist?

      test "#{File.basename(file)} can be finished by its walkthrough" do
        result = Walkthrough.run(File.read(file), File.read(script), seed: 1)
        assert result.ok?, result.failures.map { |f| "line #{f.line}: #{f.text} (#{f.detail})" }.join("\n")
        assert_not result.state["dead"], "the walkthrough ends with the player dead"
      end
    end
  end
end
