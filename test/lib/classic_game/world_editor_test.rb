# frozen_string_literal: true

require "test_helper"

module ClassicGame
  class WorldEditorTest < ActiveSupport::TestCase
    def world
      {
        "meta" => { "name" => "T", "description" => "d", "starting_room" => "start",
                    "editor" => { "rooms" => { "start" => { "x" => 0, "y" => 0 } } } },
        "rooms" => {
          "start" => { "name" => "Start", "description" => "",
                       "exits" => { "north" => "hall", "east" => { "to" => "vault", "use_item" => "key" } },
                       "items" => %w[key chest], "npcs" => ["bob"], "creatures" => [] },
          "hall" => { "name" => "Hall", "description" => "", "exits" => { "south" => "start" },
                      "items" => [], "npcs" => [], "creatures" => ["rat"] },
          "vault" => { "name" => "Vault", "description" => "", "exits" => { "west" => "start" } }
        },
        "items" => {
          "key" => { "name" => "Key", "description" => "" },
          "chest" => { "name" => "Chest", "description" => "", "is_container" => true, "contents" => ["coin"] },
          "coin" => { "name" => "Coin", "description" => "" }
        },
        "npcs" => { "bob" => { "name" => "Bob", "description" => "", "accepts_item" => "coin", "gives_item" => "key" } },
        "creatures" => { "rat" => { "name" => "Rat", "description" => "", "health" => 3, "loot" => ["coin"] } }
      }
    end

    def editor
      @editor ||= WorldEditor.new(world)
    end

    test "renaming a room rewrites every reference and keeps key order and layout" do
      editor.rename("rooms", "start", "lobby")
      w = editor.world
      assert_equal %w[lobby hall vault], w["rooms"].keys
      assert_equal "lobby", w.dig("meta", "starting_room")
      assert_equal "lobby", w.dig("rooms", "hall", "exits", "south")
      assert_equal "lobby", w.dig("rooms", "vault", "exits", "west")
      assert_equal({ "x" => 0, "y" => 0 }, w.dig("meta", "editor", "rooms", "lobby"))
      assert_nil w.dig("meta", "editor", "rooms", "start")
      assert_includes editor.changes, "renamed rooms.start to rooms.lobby"
    end

    test "renaming an item follows exits, placements, and trades" do
      editor.rename("items", "key", "brass_key")
      w = editor.world
      assert_equal "brass_key", w.dig("rooms", "start", "exits", "east", "use_item")
      assert_equal %w[brass_key chest], w.dig("rooms", "start", "items")
      assert_equal "brass_key", w.dig("npcs", "bob", "gives_item")
      assert w["items"].key?("brass_key")
      assert_not w["items"].key?("key")
    end

    test "rename refuses unknown, duplicate, and dotted ids" do
      assert_raises(WorldEditor::Error) { editor.rename("rooms", "nowhere", "x") }
      assert_raises(WorldEditor::Error) { editor.rename("rooms", "start", "hall") }
      assert_raises(WorldEditor::Error) { editor.rename("rooms", "start", "a.b") }
    end

    test "removing a room drops exits that point at it, including object exits" do
      editor.remove("rooms", "vault")
      w = editor.world
      assert_not w["rooms"].key?("vault")
      assert_equal({ "north" => "hall" }, w.dig("rooms", "start", "exits"))
      assert_includes editor.changes, "removed reference at rooms.start.exits.east.to"
    end

    test "removing an item empties every list and field that named it" do
      editor.remove("items", "coin")
      w = editor.world
      assert_equal [], w.dig("items", "chest", "contents")
      assert_equal [], w.dig("creatures", "rat", "loot")
      assert_nil w.dig("npcs", "bob", "accepts_item")
    end

    test "removing the starting room leaves meta.starting_room for the validator to report" do
      editor.remove("rooms", "start")
      assert_equal "start", editor.world.dig("meta", "starting_room")
      assert(editor.changes.any? { |c| c.include?("meta.starting_room still points") })
      assert_nil editor.world.dig("meta", "editor", "rooms", "start")
    end

    test "link adds an exit and --both adds the way back" do
      editor.link("hall", "east", "vault", both: true)
      w = editor.world
      assert_equal "vault", w.dig("rooms", "hall", "exits", "east")
      assert_equal "hall", w.dig("rooms", "vault", "exits", "west")
      assert_includes editor.changes, "retargeted rooms.vault.exits.west -> hall"
    end

    test "link keeps an object exit and only changes its target" do
      editor.link("start", "east", "hall")
      assert_equal({ "to" => "hall", "use_item" => "key" }, editor.world.dig("rooms", "start", "exits", "east"))
    end

    test "link refuses unknown rooms and directions without an opposite" do
      assert_raises(WorldEditor::Error) { editor.link("start", "north", "nowhere") }
      assert_raises(WorldEditor::Error) { editor.link("start", "through", "hall", both: true) }
    end

    test "unlink removes an exit and complains about a missing one" do
      editor.unlink("start", "north")
      assert_nil editor.world.dig("rooms", "start", "exits", "north")
      assert_raises(WorldEditor::Error) { editor.unlink("start", "north") }
    end

    test "place moves an item between rooms and into containers" do
      editor.place("key", "hall")
      w = editor.world
      assert_equal ["chest"], w.dig("rooms", "start", "items")
      assert_equal ["key"], w.dig("rooms", "hall", "items")

      editor.place("key", "chest")
      assert_equal [], w.dig("rooms", "hall", "items")
      assert_equal %w[coin key], w.dig("items", "chest", "contents")

      editor.place("coin", "vault")
      assert_equal ["key"], w.dig("items", "chest", "contents")
      assert_equal ["coin"], w.dig("rooms", "vault", "items")
    end

    test "place handles npcs and creatures and refuses bad targets" do
      editor.place("rat", "start")
      assert_equal ["rat"], editor.world.dig("rooms", "start", "creatures")
      assert_equal [], editor.world.dig("rooms", "hall", "creatures")
      assert_raises(WorldEditor::Error) { editor.place("bob", "key") }
      assert_raises(WorldEditor::Error) { editor.place("key", "coin") }
      assert_raises(WorldEditor::Error) { editor.place("ghost", "start") }
    end

    test "unplace takes an entity out of everywhere" do
      editor.unplace("coin")
      assert_equal [], editor.world.dig("items", "chest", "contents")
      editor.unplace("coin")
      assert_includes editor.changes, "item 'coin' was not placed anywhere"
    end

    test "add builds a skeleton and can place it" do
      editor.add("rooms", "attic", name: "The Attic")
      editor.add("items", "lamp", description: "Brass.", in_room: "attic")
      editor.add("creatures", "bat")
      w = editor.world
      assert_equal({ "name" => "The Attic", "description" => "", "exits" => {}, "items" => ["lamp"], "npcs" => [],
                     "creatures" => [] }, w.dig("rooms", "attic"))
      assert_equal({ "name" => "Lamp", "description" => "Brass." }, w.dig("items", "lamp"))
      assert_equal 10, w.dig("creatures", "bat", "health")
      assert_raises(WorldEditor::Error) { editor.add("items", "lamp") }
      assert_raises(WorldEditor::Error) { editor.add("flags", "x") }
      assert_raises(WorldEditor::Error) { editor.add("items", "bad id") }
    end

    test "set and delete work on dotted paths and array indexes" do
      editor.set("rooms.start.on_enter.text", "Hi")
      editor.set("rooms.start.items.0", "coin")
      editor.set("items.key.keywords", %w[key brass])
      w = editor.world
      assert_equal "Hi", w.dig("rooms", "start", "on_enter", "text")
      assert_equal %w[coin chest], w.dig("rooms", "start", "items")
      editor.delete("items.key.keywords.1")
      assert_equal ["key"], w.dig("items", "key", "keywords")
      assert_raises(WorldEditor::Error) { editor.delete("items.key.nothing") }
      assert_raises(WorldEditor::Error) { editor.set("rooms.start.name.x", 1) }
    end

    test "apply runs a batch and names the failing op" do
      editor.apply([
                     { "op" => "add", "section" => "rooms", "id" => "attic", "name" => "Attic" },
                     { "op" => "link", "room" => "hall", "direction" => "up", "to" => "attic", "both" => true },
                     { "op" => "set", "path" => "rooms.attic.description", "value" => "Dusty." }
                   ])
      assert_equal "hall", editor.world.dig("rooms", "attic", "exits", "down")
      error = assert_raises(WorldEditor::Error) do
        editor.apply([{ "op" => "set", "path" => "meta.version", "value" => "2" }, { "op" => "rm", "section" => "rooms", "id" => "nope" }])
      end
      assert_match(/op 2 \(rm\)/, error.message)
      assert_raises(WorldEditor::Error) { editor.apply([{ "op" => "explode" }]) }
      assert_raises(WorldEditor::Error) { editor.apply({ "op" => "add" }) }
    end
  end
end
