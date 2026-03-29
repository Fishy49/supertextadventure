# frozen_string_literal: true

require "test_helper"

class CommandParserTest < ActiveSupport::TestCase
  # ─── Directions ─────────────────────────────────────────────────────────────

  test "single direction shorthand maps to go + direction" do
    {
      "n" => :north, "s" => :south, "e" => :east, "w" => :west,
      "ne" => :northeast, "nw" => :northwest, "se" => :southeast, "sw" => :southwest,
      "u" => :up, "d" => :down
    }.each do |input, expected_dir|
      result = ClassicGame::CommandParser.parse(input)
      assert_equal :go, result[:verb], "Expected :go for '#{input}'"
      assert_equal expected_dir, result[:target], "Expected #{expected_dir} for '#{input}'"
    end
  end

  test "full direction names map to go + direction" do
    result = ClassicGame::CommandParser.parse("north")
    assert_equal :go, result[:verb]
    assert_equal :north, result[:target]
  end

  test "go [direction] parses direction as target" do
    result = ClassicGame::CommandParser.parse("go north")
    assert_equal :go, result[:verb]
    assert_equal :north, result[:target]
  end

  test "go [direction] strips prepositions" do
    result = ClassicGame::CommandParser.parse("go to the north")
    assert_equal :go, result[:verb]
    assert_equal :north, result[:target]
  end

  # ─── Verb synonyms ──────────────────────────────────────────────────────────

  test "take synonyms" do
    %w[take get grab pickup].each do |word|
      result = ClassicGame::CommandParser.parse("#{word} sword")
      assert_equal :take, result[:verb], "Expected :take for '#{word}'"
    end
  end

  test "examine synonyms" do
    %w[examine inspect x check read].each do |word|
      result = ClassicGame::CommandParser.parse("#{word} scroll")
      assert_equal :examine, result[:verb], "Expected :examine for '#{word}'"
    end
  end

  test "attack synonyms" do
    %w[attack kill hit strike fight].each do |word|
      result = ClassicGame::CommandParser.parse("#{word} goblin")
      assert_equal :attack, result[:verb], "Expected :attack for '#{word}'"
    end
  end

  test "flee synonyms" do
    %w[flee run escape retreat].each do |word|
      result = ClassicGame::CommandParser.parse(word)
      assert_equal :flee, result[:verb], "Expected :flee for '#{word}'"
    end
  end

  # ─── Target extraction ──────────────────────────────────────────────────────

  test "take strips articles from target" do
    result = ClassicGame::CommandParser.parse("take the golden key")
    assert_equal :take, result[:verb]
    assert_equal "golden key", result[:target]
  end

  test "look with no target returns nil target" do
    result = ClassicGame::CommandParser.parse("look")
    assert_equal :look, result[:verb]
    assert_nil result[:target]
  end

  test "examine with target" do
    result = ClassicGame::CommandParser.parse("examine ancient sword")
    assert_equal :examine, result[:verb]
    assert_equal "ancient sword", result[:target]
  end

  test "inventory has no target" do
    %w[inventory inv i].each do |word|
      result = ClassicGame::CommandParser.parse(word)
      assert_equal :inventory, result[:verb], "Expected :inventory for '#{word}'"
      assert_nil result[:target]
    end
  end

  # ─── Modifier extraction (USE / GIVE / TALK) ─────────────────────────────

  test "use [item] on [target] extracts both target and modifier" do
    result = ClassicGame::CommandParser.parse("use key on door")
    assert_equal :use, result[:verb]
    assert_equal "key", result[:target]
    assert_equal "door", result[:modifier]
  end

  test "give [item] to [npc] extracts both target and modifier" do
    result = ClassicGame::CommandParser.parse("give sword to innkeeper")
    assert_equal :give, result[:verb]
    assert_equal "sword", result[:target]
    assert_equal "innkeeper", result[:modifier]
  end

  test "talk to [npc] puts npc in modifier" do
    result = ClassicGame::CommandParser.parse("talk to innkeeper")
    assert_equal :talk, result[:verb]
    assert_equal "innkeeper", result[:modifier]
  end

  test "attack [creature] with no modifier" do
    result = ClassicGame::CommandParser.parse("attack goblin")
    assert_equal :attack, result[:verb]
    assert_equal "goblin", result[:target]
    assert_nil result[:modifier]
  end

  # ─── Special commands ───────────────────────────────────────────────────────

  test "help command" do
    %w[help h ?].each do |word|
      result = ClassicGame::CommandParser.parse(word)
      assert_equal :help, result[:verb], "Expected :help for '#{word}'"
    end
  end

  test "restart command" do
    result = ClassicGame::CommandParser.parse("restart")
    assert_equal :restart, result[:verb]
  end

  test "defend command" do
    result = ClassicGame::CommandParser.parse("defend")
    assert_equal :defend, result[:verb]
    assert_nil result[:target]
  end

  test "roll command parses correctly" do
    result = ClassicGame::CommandParser.parse("roll")
    assert_equal :roll, result[:verb]
    assert_nil result[:target]
  end

  # ─── Edge cases ─────────────────────────────────────────────────────────────

  test "blank input returns unknown verb" do
    result = ClassicGame::CommandParser.parse("")
    assert_equal :unknown, result[:verb]
  end

  test "unrecognized word returns unknown verb" do
    result = ClassicGame::CommandParser.parse("flibbertigibbet")
    assert_equal :unknown, result[:verb]
  end

  test "preserves raw input unchanged" do
    result = ClassicGame::CommandParser.parse("Go NORTH")
    assert_equal "Go NORTH", result[:raw]
  end

  test "parsing is case-insensitive" do
    result = ClassicGame::CommandParser.parse("TAKE SWORD")
    assert_equal :take, result[:verb]
    assert_equal "sword", result[:target]
  end
end
