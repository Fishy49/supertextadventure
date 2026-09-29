# frozen_string_literal: true

require "test_helper"
require "open3"

module ClassicGame
  # The browser builder validates worlds with app/javascript/world_builder/contract.js.
  # It must produce exactly the codes the Ruby validator produces for every fixture.
  class ContractParityTest < ActiveSupport::TestCase
    SCRIPT = Rails.root.join("test/support/contract_parity.mjs")
    FIXTURES = Rails.root.join("test/fixtures/files/worlds")

    test "the JavaScript validator agrees with the Ruby validator on every fixture" do
      output, status = begin
        Open3.capture2(ENV.fetch("NODE", "node"), SCRIPT.to_s)
      rescue Errno::ENOENT
        skip "node is not installed, so the JavaScript validator cannot run here"
      end
      assert status.success?, output

      results = JSON.parse(output)
      assert results.keys.any? { |k| k.start_with?("invalid/") }, "no fixtures were checked"
      results.each do |file, js_codes|
        path = file.start_with?("games/") ? Rails.root.join(file) : FIXTURES.join(file)
        ruby_codes = WorldValidator.new(File.read(path)).errors.pluck(:code).sort.uniq
        assert_equal ruby_codes, js_codes.sort.uniq, "#{file}: Ruby #{ruby_codes.inspect} vs JavaScript #{js_codes.inspect}"
      end
    end
  end
end
