# frozen_string_literal: true

require "test_helper"

module ClassicGame
  class WorldLinterTest < ActiveSupport::TestCase
    FIXTURES = Rails.root.join("test/fixtures/files/worlds")

    Dir[FIXTURES.join("lint/*.json")].reject { |f| f.end_with?(".expected.json") }.sort.each do |file|
      test "lint fixture #{File.basename(file)} produces its expected code and path pairs" do
        expected = JSON.parse(File.read(file.sub(/\.json\z/, ".expected.json"))).fetch("lint")
        linter = WorldLinter.new(File.read(file))
        assert_empty linter.errors, "lint fixtures must satisfy the contract"
        pairs = linter.lint_problems.map { |p| "#{p[:code]} #{p[:path]}" }.sort.uniq
        assert_equal expected.sort.uniq, pairs, linter.lint_problems.map { |p| "#{p[:code]} #{p[:path]}: #{p[:message]}" }.join("\n")
      end
    end

    Rails.root.glob("games/*.json").each do |file|
      test "shipped world #{File.basename(file)} has no errors or warnings" do
        linter = WorldLinter.new(File.read(file))
        problems = linter.errors + linter.warnings
        assert_empty problems, problems.map { |p| "#{p[:code]} #{p[:path]}: #{p[:message]}" }.join("\n")
      end
    end

    test "every lint code is documented and known" do
      assert_equal WorldLinter::LINT_CODES.sort, WorldLinter::LINT_CODES.uniq.sort
      Dir[FIXTURES.join("lint/*.expected.json")].each do |file|
        JSON.parse(File.read(file)).fetch("lint").each do |pair|
          assert_includes WorldLinter::LINT_CODES, pair.split.first, "#{File.basename(file)} expects an unknown code"
        end
      end
    end

    test "contract errors are included at level error with an owner target" do
      world = JSON.parse(File.read(FIXTURES.join("invalid/exit_to_unknown_room.json")))
      problems = WorldLinter.new(world).problems
      error = problems.find { |p| p[:level] == "error" }
      assert error, "expected a contract error"
      assert_equal "ref.missing", error[:code]
      assert_equal "room", error[:target][:type]
    end

    test "flag problems target the flag itself" do
      world = JSON.parse(File.read(FIXTURES.join("lint/flags.json")))
      problem = WorldLinter.new(world).lint_problems.find { |p| p[:code] == "flag.never_set" }
      assert_equal({ type: "flag", id: "gate_open" }, problem[:target])
      assert_equal "warn", problem[:level]
      assert_match(/rooms\.start\.exits\.north\.requires_flag/, problem[:message])
    end

    test "a world that is not an object lints without raising" do
      problems = WorldLinter.new("[]").problems
      assert(problems.all? { |p| p[:level] == "error" })
      assert_not_empty problems
    end
  end
end
