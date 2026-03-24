# frozen_string_literal: true

require "test_helper"

class InteractHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  INNKEEPER_NPC = {
    "name" => "Innkeeper",
    "keywords" => ["innkeeper"],
    "dialogue" => {
      "greeting" => "Welcome, traveller. What brings you to these parts?",
      "default" => "I wouldn't know anything about that.",
      "topics" => {
        "town" => {
          "keywords" => %w[town village quiet],
          "text" => "The town's been quiet since the mine closed. Folk are scared.",
          "leads_to" => ["mine"]
        },
        "mine" => {
          "keywords" => %w[mine collapse closed],
          "text" => "Nobody's been down there since the collapse.",
          "locked_text" => "I'm not sure what you mean."
        },
        "work" => {
          "keywords" => %w[work job help],
          "text" => "I need someone to clear the rats from my cellar.",
          "sets_flag" => "rat_quest_started"
        },
        "reward" => {
          "keywords" => %w[reward payment done],
          "requires_flag" => "rats_cleared",
          "text" => "You did it! Here's what I promised.",
          "locked_text" => "Bring me proof the rats are gone first."
        },
        "appraisal" => {
          "keywords" => %w[appraise appraisal worth],
          "requires_item" => "sword",
          "text" => "Fine craftsmanship. That blade is worth 50 gold.",
          "locked_text" => "Bring me something worth appraising."
        }
      }
    }
  }.freeze

  SILENT_GUARD = {
    "name" => "Guard",
    "keywords" => ["guard"]
    # no "dialogue" key
  }.freeze

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "Tavern",
          "description" => "A warm tavern.",
          "exits" => {},
          "npcs" => %w[innkeeper guard]
        }
      },
      items: {
        "sword" => { "name" => "Iron Sword", "keywords" => %w[sword iron], "takeable" => true }
      },
      npcs: {
        "innkeeper" => INNKEEPER_NPC.dup,
        "guard" => SILENT_GUARD.dup
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID)
  end

  # ─── Greeting ───────────────────────────────────────────────────────────────

  test "talk to npc with no topic returns greeting" do
    result = execute("talk to innkeeper")

    assert result[:success]
    assert_includes result[:response], "Welcome, traveller"
  end

  test "talk response wraps text in npc-says format" do
    result = execute("talk to innkeeper")

    assert_includes result[:response], 'Innkeeper says: "'
  end

  # ─── Topic matching ─────────────────────────────────────────────────────────

  test "talk about topic matches by keyword" do
    result = execute("talk to innkeeper about town")

    assert result[:success]
    assert_includes result[:response], "mine closed"
  end

  test "talk about topic matches alternate keyword in topic" do
    result = execute("talk to innkeeper about village")

    assert_includes result[:response], "mine closed"
  end

  # ─── leads_to gating ────────────────────────────────────────────────────────

  test "subtopic locked before parent topic accessed" do
    result = execute("talk to innkeeper about mine")

    assert result[:success]
    assert_includes result[:response], "I'm not sure what you mean"
  end

  test "subtopic accessible after parent topic accessed" do
    execute("talk to innkeeper about town")
    result = execute("talk to innkeeper about mine")

    assert_includes result[:response], "Nobody's been down there"
  end

  test "accessing parent topic records subtopic in player dialogue_unlocked" do
    execute("talk to innkeeper about town")

    unlocked = @game.player_state(USER_ID).dig("dialogue_unlocked", "innkeeper")
    assert_includes unlocked, "mine"
  end

  # ─── requires_flag ──────────────────────────────────────────────────────────

  test "topic with requires_flag returns locked_text when flag not set" do
    result = execute("talk to innkeeper about reward")

    assert_includes result[:response], "Bring me proof"
  end

  test "topic with requires_flag returns text when flag is set" do
    @game.set_flag("rats_cleared", true)
    result = execute("talk to innkeeper about reward")

    assert_includes result[:response], "You did it"
  end

  # ─── requires_item ──────────────────────────────────────────────────────────

  test "topic with requires_item returns locked_text when item not in inventory" do
    result = execute("talk to innkeeper about appraisal")

    assert_includes result[:response], "Bring me something worth appraising"
  end

  test "topic with requires_item returns text when item in inventory" do
    @game = build_game(
      world_data: @world,
      player_id: USER_ID,
      player_state: player_state_in("tavern", inventory: ["sword"])
    )
    result = execute("talk to innkeeper about appraisal")

    assert_includes result[:response], "Fine craftsmanship"
  end

  # ─── sets_flag ──────────────────────────────────────────────────────────────

  test "accessing topic with sets_flag sets the flag" do
    execute("talk to innkeeper about work")

    assert @game.get_flag("rat_quest_started")
  end

  # ─── Default / no match ─────────────────────────────────────────────────────

  test "talk about unrecognized topic returns default response" do
    result = execute("talk to innkeeper about dragons")

    assert result[:success]
    assert_includes result[:response], "I wouldn't know anything about that"
  end

  # ─── NPC has no dialogue ────────────────────────────────────────────────────

  test "talk to npc with no dialogue returns not interested message" do
    result = execute("talk to guard")

    assert_not result[:success]
    assert_includes result[:response], "Guard doesn't seem interested in talking"
  end

  # ─── NPC with dialogue but no topics ───────────────────────────────────────

  test "talk to npc with dialogue but no topics returns greeting" do
    shopkeeper_npc = {
      "name" => "Shopkeeper",
      "keywords" => ["shopkeeper"],
      "dialogue" => { "greeting" => "Hello there." }
    }
    world = build_world(
      starting_room: "shop",
      rooms: {
        "shop" => {
          "name" => "Shop", "description" => "A small shop.", "exits" => {},
          "npcs" => ["shopkeeper"]
        }
      },
      npcs: { "shopkeeper" => shopkeeper_npc }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    command = ClassicGame::CommandParser.parse("talk to shopkeeper")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert_includes result[:response], "Hello there."
  end

  # ─── NPC not in room ────────────────────────────────────────────────────────

  test "talk to npc not in current room fails" do
    world = build_world(
      starting_room: "empty_room",
      rooms: {
        "empty_room" => {
          "name" => "Empty Room", "description" => "Nothing here.", "exits" => {},
          "npcs" => []
        }
      },
      npcs: { "innkeeper" => INNKEEPER_NPC.dup }
    )
    game = build_game(world_data: world, player_id: USER_ID)
    command = ClassicGame::CommandParser.parse("talk to innkeeper")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert_not result[:success]
    assert_includes result[:response], "don't see anyone"
  end

  # ─── No target ──────────────────────────────────────────────────────────────

  test "talk with no target fails" do
    result = execute("talk")

    assert_not result[:success]
    assert_includes result[:response], "whom"
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::InteractHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
