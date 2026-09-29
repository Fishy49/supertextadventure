# frozen_string_literal: true

require "test_helper"

module ClassicGame
  class PlaythroughTest < ActiveSupport::TestCase
    WORLD = Rails.root.join("games/the_crystal_quest.json")

    def world
      JSON.parse(File.read(WORLD))
    end

    test "intro describes the starting room like a real game does" do
      intro = Playthrough.new(world).intro
      assert_includes intro, "=== The Rusty Flagon ==="
      assert_includes intro, "You see: Rusty Sword, Wooden Chest, Faded Map"
      assert_includes intro, "Present: Old Wizard"
      assert_includes intro, "Exits: NORTH"
    end

    test "commands run through the engine and update the state" do
      play = Playthrough.new(world, seed: 1)
      turn = play.run("take sword")
      assert turn.success
      assert_equal "You take the Rusty Sword.", turn.response
      play.run("north")
      state = play.state
      assert_equal "forest_edge", state["room"]
      assert_equal ["rusty_sword"], state["inventory"]
      assert_equal 10, state["health"]
      assert_equal 2, play.transcript.size
      assert_not state["dead"]
    end

    test "the source world is not mutated by playing" do
      source = world
      play = Playthrough.new(source)
      play.run("take sword")
      assert_equal %w[rusty_sword tavern_chest old_map], source.dig("rooms", "tavern", "items")
    end

    test "walkthrough scripts run commands and check expectations" do
      script = <<~SCRIPT
        # Grab the sword and head north.
        take sword
        expect has rusty_sword
        expect not has rusty_key
        expect says you take the rusty sword

        north
        expect room forest_edge
        expect health >= 5
        expect health 10
        expect not flag met_wizard
      SCRIPT
      result = Walkthrough.run(world, script, seed: 1)
      assert result.ok?, result.failures.map { |f| "#{f.line}: #{f.text} (#{f.detail})" }.join("\n")
      assert_equal 7, result.expectations.size
      assert_equal(2, result.steps.count { |s| s.kind == :command })
      assert_equal 1, result.seed
    end

    test "failed expectations carry the line and a detail" do
      result = Walkthrough.run(world, "north\nexpect room tavern\nexpect flag nope\nexpect health > 50\nexpect banana\n")
      assert_not result.ok?
      lines = result.failures.map(&:line)
      assert_equal [2, 3, 4, 5], lines
      assert_equal "room is forest_edge", result.failures.first.detail
      assert_match(/expect needs one of/, result.failures.last.detail)
    end
  end
end
