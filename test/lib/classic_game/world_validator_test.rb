# frozen_string_literal: true

require "test_helper"

module ClassicGame
  class WorldValidatorTest < ActiveSupport::TestCase
    FIXTURES = Rails.root.join("test/fixtures/files/worlds")

    Dir[FIXTURES.join("valid/*.json")].each do |file|
      test "valid fixture #{File.basename(file)} has no errors" do
        errors = WorldValidator.new(File.read(file)).errors
        assert_empty errors, errors.pluck(:message).join("\n")
      end
    end

    Dir[FIXTURES.join("invalid/*.json")].reject { |f| f.end_with?(".expected.json") }.sort.each do |file|
      test "invalid fixture #{File.basename(file)} produces its expected codes" do
        expected = JSON.parse(File.read(file.sub(/\.json\z/, ".expected.json"))).fetch("codes")
        errors = WorldValidator.new(File.read(file)).errors
        assert_equal expected.sort.uniq, errors.pluck(:code).sort.uniq,
                     errors.map { |e| "#{e[:code]} #{e[:path]}: #{e[:message]}" }.join("\n")
      end
    end

    Rails.root.glob("games/*.json").each do |file|
      test "shipped world #{File.basename(file)} validates" do
        errors = WorldValidator.new(File.read(file)).errors
        assert_empty errors, errors.pluck(:message).join("\n")
      end
    end

    test "the QA world fixture validates" do
      errors = WorldValidator.new(TestSupport::QaWorldData.data).errors
      assert_empty errors, errors.pluck(:message).join("\n")
    end

    test "errors carry a stable code, a dotted path, and a message" do
      world = minimal_world
      world["meta"]["starting_room"] = "nowhere"
      errors = WorldValidator.new(world).errors

      assert_equal 1, errors.size
      assert_equal "starting_room.missing", errors.first[:code]
      assert_equal "meta.starting_room", errors.first[:path]
      assert_includes errors.first[:message], "nowhere"
    end

    test "every invalid fixture's expected codes come from the documented set" do
      documented = %w[schema.invalid starting_room.missing ref.missing topic.missing dice.outcomes dice.consume_on
                      attack_condition.invalid]
      Dir[FIXTURES.join("invalid/*.expected.json")].each do |file|
        JSON.parse(File.read(file)).fetch("codes").each do |code|
          assert_includes documented, code, "#{File.basename(file)} expects undocumented code #{code}"
        end
      end
    end

    test "accepts symbol keys and JSON strings" do
      symbols = { meta: { name: "S", description: "s", starting_room: "start" },
                  rooms: { start: { name: "Start", description: "A room.", exits: {} } } }
      assert_empty WorldValidator.new(symbols).errors
      assert_empty WorldValidator.new(JSON.generate(minimal_world)).errors
    end

    test "engine validate_world_data keeps returning messages" do
      world = minimal_world
      world["rooms"]["start"]["items"] = ["pick"]
      world["items"] = { "pick" => { "name" => "Pick", "description" => "A pick.",
                                     "dice_roll" => { "dc" => 10, "on_success" => { "message" => "ok" } } } }
      messages = Engine.validate_world_data(world)
      assert_includes messages, "Item 'pick' has a dice_roll missing on_success or on_failure."
      assert_empty Engine.validate_world_data(minimal_world)
    end

    test "World refuses to save an invalid world and reports why" do
      world = World.new(name: "Broken", description: "A broken world", world_data: minimal_world)
      world.world_data["rooms"]["start"]["exits"] = { "north" => "nowhere" }

      assert_not world.save
      assert world.errors[:world_data].any? { |m| m.include?("nowhere") }, world.errors.full_messages.join("\n")
    end

    test "a fresh World starts with a valid skeleton" do
      world = World.new(name: "Fresh", description: "A brand new world")
      assert world.valid?, world.errors.full_messages.join("\n")
      assert_equal "Fresh", world.world_data.dig("meta", "name")
      assert world.world_data.dig("rooms", world.starting_room)
    end

    private

      def minimal_world
        JSON.parse(File.read(FIXTURES.join("valid/minimal.json")))
      end
  end
end
