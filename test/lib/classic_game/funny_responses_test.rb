# frozen_string_literal: true

require "test_helper"

class FunnyResponsesTest < ActiveSupport::TestCase
  FunnyResponses = ClassicGame::FunnyResponses

  test "unknown_command returns string containing raw input and key phrase" do
    result = FunnyResponses.unknown_command("xyzzy")
    assert_kind_of String, result
    assert_includes result, "xyzzy"
    assert_includes result.downcase, "don't understand"
  end

  test "unknown_command varies across calls" do
    results = Array.new(50) { FunnyResponses.unknown_command("x") }.uniq
    assert results.size > 1, "Expected multiple unique responses but got only #{results.size}"
  end

  test "cant_go includes key phrase" do
    result = FunnyResponses.cant_go
    assert_kind_of String, result
    assert_includes result.downcase, "can't go"
  end

  test "go_where includes key phrase" do
    result = FunnyResponses.go_where
    assert_kind_of String, result
    assert_includes result.downcase, "go where"
  end

  test "take_what includes key phrase" do
    result = FunnyResponses.take_what
    assert_kind_of String, result
    assert_includes result.downcase, "take what"
  end

  test "drop_what includes key phrase" do
    result = FunnyResponses.drop_what
    assert_kind_of String, result
    assert_includes result.downcase, "drop what"
  end

  test "use_what includes key phrase" do
    result = FunnyResponses.use_what
    assert_kind_of String, result
    assert_includes result.downcase, "use what"
  end

  test "examine_what includes key phrase" do
    result = FunnyResponses.examine_what
    assert_kind_of String, result
    assert_includes result.downcase, "examine what"
  end

  test "open_what includes key phrase" do
    result = FunnyResponses.open_what
    assert_kind_of String, result
    assert_includes result.downcase, "open what"
  end

  test "close_what includes key phrase" do
    result = FunnyResponses.close_what
    assert_kind_of String, result
    assert_includes result.downcase, "close what"
  end

  test "talk_to_whom includes key phrase" do
    result = FunnyResponses.talk_to_whom
    assert_kind_of String, result
    assert_includes result.downcase, "talk to whom"
  end

  test "attack_what includes key phrase" do
    result = FunnyResponses.attack_what
    assert_kind_of String, result
    assert_includes result.downcase, "attack what"
  end

  test "dont_see_that includes key phrase" do
    result = FunnyResponses.dont_see_that
    assert_kind_of String, result
    assert_includes result.downcase, "don't see"
  end

  test "dont_have_that includes key phrase" do
    result = FunnyResponses.dont_have_that
    assert_kind_of String, result
    assert_includes result.downcase, "don't have"
  end

  test "cant_use_here includes key phrase" do
    result = FunnyResponses.cant_use_here
    assert_kind_of String, result
    assert_includes result.downcase, "can't use"
  end

  test "nothing_special includes key phrase" do
    result = FunnyResponses.nothing_special
    assert_kind_of String, result
    assert_includes result.downcase, "nothing special"
  end

  test "each pool has multiple entries" do
    assert FunnyResponses::UNKNOWN_COMMAND.size >= 3
    assert FunnyResponses::CANT_GO.size >= 3
    assert FunnyResponses::GO_WHERE.size >= 3
    assert FunnyResponses::TAKE_WHAT.size >= 3
    assert FunnyResponses::DROP_WHAT.size >= 3
    assert FunnyResponses::USE_WHAT.size >= 3
    assert FunnyResponses::EXAMINE_WHAT.size >= 3
    assert FunnyResponses::OPEN_WHAT.size >= 3
    assert FunnyResponses::CLOSE_WHAT.size >= 3
    assert FunnyResponses::TALK_TO_WHOM.size >= 3
    assert FunnyResponses::ATTACK_WHAT.size >= 3
    assert FunnyResponses::DONT_SEE_THAT.size >= 3
    assert FunnyResponses::DONT_HAVE_THAT.size >= 3
    assert FunnyResponses::CANT_USE_HERE.size >= 3
    assert FunnyResponses::NOTHING_SPECIAL.size >= 3
  end
end
