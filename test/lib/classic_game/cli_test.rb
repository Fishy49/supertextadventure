# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module ClassicGame
  class CliTest < ActiveSupport::TestCase
    setup do
      @dir = Dir.mktmpdir("world-cli")
      @file = File.join(@dir, "test.json")
    end

    teardown do
      FileUtils.remove_entry(@dir)
    end

    # Returns [status, stdout, stderr].
    def world(*args, stdin: "")
      out = StringIO.new
      err = StringIO.new
      status = Cli.new(args.map(&:to_s), stdout: out, stderr: err, stdin: StringIO.new(stdin)).run
      [status, out.string, err.string]
    end

    def data
      JSON.parse(File.read(@file))
    end

    test "help lists every command and exits 0" do
      status, out, = world("help")
      assert_equal 0, status
      Cli::COMMANDS.each { |c| assert_includes out, c[0] }
      status, out, = world("help", "play")
      assert_equal 0, status
      assert_includes out, "--script FILE"
    end

    test "unknown commands and bad usage exit 2" do
      status, _, err = world("frobnicate")
      assert_equal 2, status
      assert_match(/unknown command/, err)
      status, _, err = world("check")
      assert_equal 2, status
      assert_match(%r{usage: bin/world check}, err)
      status, out, = world("check", "--json")
      assert_equal 2, status
      assert_equal false, JSON.parse(out)["ok"]
      status, _, err = world("check", File.join(@dir, "missing.json"))
      assert_equal 2, status
      assert_match(/no such file/, err)
    end

    test "new, add, link, place, set, and check build a valid world" do
      status, out, = world("new", @file, "--name", "Cli World", "--description", "Built by tests")
      assert_equal 0, status
      assert_includes out, "0 errors, 0 warnings"
      assert_equal "Cli World", data.dig("meta", "name")
      assert_equal 2, world("new", @file).first

      assert_equal 0, world("add", @file, "rooms", "hall", "--name", "The Hall", "--description", "Long.").first
      assert_equal 0, world("link", @file, "start", "north", "hall", "--both").first
      assert_equal "start", data.dig("rooms", "hall", "exits", "south")

      assert_equal 0, world("add", @file, "items", "key", "--in", "start").first
      assert_equal ["key"], data.dig("rooms", "start", "items")
      assert_equal 0, world("set", @file, "items.key.description", "A small key.").first
      assert_equal 0, world("set", @file, "items.key.takeable", "false").first
      assert_equal 0, world("set", @file, "items.key.keywords", '["key","small key"]').first
      assert_equal false, data.dig("items", "key", "takeable")
      assert_equal ["key", "small key"], data.dig("items", "key", "keywords")

      status, out, = world("check", @file, "--json")
      assert_equal 0, status
      report = JSON.parse(out)
      assert report["ok"]
      assert_equal 0, report["counts"]["error"]
    end

    test "show, ls, graph, and refs read the world back" do
      world("new", @file)
      world("add", @file, "rooms", "hall")
      world("link", @file, "start", "north", "hall", "--both")
      world("add", @file, "items", "key", "--in", "hall")

      status, out, = world("show", @file)
      assert_equal 0, status
      assert_includes out, "starting room: start"
      assert_includes out, "rooms 2, items 1"

      _, out, = world("show", @file, "items.key")
      assert_equal "Key", JSON.parse(out)["name"]
      assert_equal 2, world("show", @file, "items.nothing").first

      _, out, = world("ls", @file, "items")
      assert_equal "key\tKey\tin: hall", out.strip
      _, out, = world("ls", @file, "items", "--in", "start")
      assert_equal "", out.strip
      _, out, = world("ls", @file, "rooms", "--json")
      assert_equal(%w[start hall], JSON.parse(out).pluck("id"))
      assert_equal 2, world("ls", @file, "planets").first

      _, out, = world("graph", @file)
      assert_includes out, "start  Starting Room"
      assert_includes out, "  north -> hall"

      _, out, = world("refs", @file, "hall")
      assert_includes out, "rooms.start.exits.north\troom ref"
      _, out, = world("refs", @file, "ghost")
      assert_includes out, "no references to 'ghost'"
    end

    test "rename and rm cascade, and edits that break the world exit 1 but still write" do
      world("new", @file)
      world("add", @file, "rooms", "hall")
      world("link", @file, "start", "north", "hall", "--both")
      world("add", @file, "items", "key", "--in", "hall")

      status, out, = world("rename", @file, "items", "key", "brass_key")
      assert_equal 0, status
      assert_includes out, "updated rooms.hall.items.0"
      assert_equal ["brass_key"], data.dig("rooms", "hall", "items")

      assert_equal 0, world("rm", @file, "rooms", "hall").first
      assert_equal({}, data.dig("rooms", "start", "exits"))

      status, out, = world("set", @file, "meta.starting_room", "nowhere")
      assert_equal 1, status
      assert_includes out, "starting_room.missing"
      assert_equal "nowhere", data.dig("meta", "starting_room")

      status, out, = world("check", @file)
      assert_equal 1, status
      assert_includes out, "1 errors"
    end

    test "del removes a path and unplace and unlink undo placements and exits" do
      world("new", @file)
      world("add", @file, "rooms", "hall")
      world("link", @file, "start", "north", "hall")
      world("add", @file, "items", "key", "--in", "hall")
      assert_equal 0, world("unplace", @file, "key").first
      assert_equal [], data.dig("rooms", "hall", "items")
      assert_equal 0, world("unlink", @file, "start", "north").first
      assert_equal 0, world("del", @file, "items.key").first
      assert_nil data.dig("items", "key")
      assert_equal 2, world("del", @file, "items.key").first
    end

    test "apply reads operations from a file or stdin" do
      world("new", @file)
      ops = [{ "op" => "add", "section" => "rooms", "id" => "hall" },
             { "op" => "link", "room" => "start", "direction" => "north", "to" => "hall", "both" => true }]
      status, out, = world("apply", @file, "-", "--json", stdin: JSON.generate(ops))
      assert_equal 0, status
      assert JSON.parse(out)["ok"]
      assert_equal "start", data.dig("rooms", "hall", "exits", "south")

      ops_file = File.join(@dir, "ops.json")
      File.write(ops_file, JSON.generate([{ "op" => "rm", "section" => "rooms", "id" => "nope" }]))
      status, _, err = world("apply", @file, ops_file)
      assert_equal 2, status
      assert_match(/op 1 \(rm\)/, err)
    end

    test "play runs commands, scripts, and stdin through the engine" do
      world("new", @file)
      status, out, = world("play", @file, "--commands", "look; inventory")
      assert_equal 0, status
      assert_includes out, "=== Starting Room ==="
      assert_includes out, "> inventory"
      assert_includes out, "room: start"

      script = File.join(@dir, "walk.txt")
      File.write(script, "look\nexpect room start\nexpect room elsewhere\n")
      status, out, = world("play", @file, "--script", script)
      assert_equal 1, status
      assert_includes out, "[FAIL] line 3: expect room elsewhere  (room is start)"
      assert_includes out, "1 of 2 expectations passed"

      status, out, = world("play", @file, "--json", stdin: "look\nexpect room start\n")
      assert_equal 0, status
      result = JSON.parse(out)
      assert result["ok"]
      assert_equal(%w[command expect], result["steps"].pluck("kind"))
      assert_equal "start", result.dig("state", "room")
    end

    test "explain lists codes and describes one" do
      status, out, = world("explain")
      assert_equal 0, status
      assert_includes out, "item.unplaced"
      status, out, = world("explain", "room.unreachable", "--json")
      assert_equal 0, status
      assert_includes JSON.parse(out)["fix"], "bin/world link"
      assert_equal 2, world("explain", "nope").first
    end

    test "every contract and lint code has an explanation" do
      codes = %w[schema.invalid starting_room.missing ref.missing topic.missing
                 dice.outcomes dice.consume_on attack_condition.invalid]
      (codes + WorldLinter::LINT_CODES).each do |code|
        assert Cli::Inspect::EXPLANATIONS.key?(code), "no explanation for #{code}"
      end
    end
  end
end
