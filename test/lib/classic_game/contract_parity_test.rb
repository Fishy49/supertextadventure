# frozen_string_literal: true

require "test_helper"
require "open3"

module ClassicGame
  # The browser builder validates and lints worlds with
  # app/javascript/world_builder/contract.js. It must produce exactly the
  # error codes and the lint code/path pairs the Ruby side produces for every
  # fixture and every shipped game.
  class ContractParityTest < ActiveSupport::TestCase
    SCRIPT = Rails.root.join("test/support/contract_parity.mjs")
    FIXTURES = Rails.root.join("test/fixtures/files/worlds")

    test "the JavaScript contract agrees with the Ruby validator and linter on every fixture" do
      output, status = begin
        Open3.capture2(ENV.fetch("NODE", "node"), SCRIPT.to_s)
      rescue Errno::ENOENT
        skip "node is not installed, so the JavaScript contract cannot run here"
      end
      assert status.success?, output

      results = JSON.parse(output)
      assert results.keys.any? { |k| k.start_with?("invalid/") }, "no invalid fixtures were checked"
      assert results.keys.any? { |k| k.start_with?("lint/") }, "no lint fixtures were checked"
      results.each do |file, js|
        path = file.start_with?("games/") ? Rails.root.join(file) : FIXTURES.join(file)
        source = File.read(path)
        ruby_codes = WorldValidator.new(source).errors.pluck(:code).sort.uniq
        assert_equal ruby_codes, js["errors"], "#{file}: Ruby errors #{ruby_codes.inspect} vs JavaScript #{js['errors'].inspect}"
        ruby_lint = WorldLinter.new(source).lint_problems.map { |p| "#{p[:code]} #{p[:path]}" }.sort.uniq
        assert_equal ruby_lint, js["lint"], "#{file}: Ruby lint #{ruby_lint.inspect} vs JavaScript #{js['lint'].inspect}"
      end
    end
  end
end
