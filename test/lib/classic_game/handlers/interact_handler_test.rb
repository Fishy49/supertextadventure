# frozen_string_literal: true

require "test_helper"

class InteractHandlerTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  setup do
    @world = build_world(
      starting_room: "tavern",
      rooms: {
        "tavern" => {
          "name" => "The Tavern",
          "description" => "A cozy inn.",
          "exits" => {},
          "npcs" => %w[innkeeper guard greeter]
        }
      },
      npcs: {
        "innkeeper" => {
          "name" => "Innkeeper",
          "keywords" => %w[innkeeper keeper],
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
        },
        "guard" => {
          "name" => "Guard",
          "keywords" => ["guard"]
        },
        "greeter" => {
          "name" => "Greeter",
          "keywords" => ["greeter"],
          "dialogue" => {
            "greeting" => "Hello."
          }
        }
      },
      items: {
        "sword" => { "name" => "Sword", "keywords" => ["sword"], "takeable" => true }
      }
    )
    @game = build_game(world_data: @world, player_id: USER_ID)
  end

  # ─── GREETING ──────────────────────────────────────────────────────────────

  test "talk to npc with no topic returns greeting" do
    result = execute("talk to innkeeper")

    assert result[:success]
    assert_includes result[:response], "Innkeeper says:"
    assert_includes result[:response], "Welcome, traveller."
  end

  # ─── KEYWORD MATCHING ─────────────────────────────────────────────────────

  test "talk to npc about topic matches by keyword" do
    result = execute("talk to innkeeper about village")

    assert result[:success]
    assert_includes result[:response], "Innkeeper says:"
    assert_includes result[:response], "The town's been quiet"
  end

  test "talk to npc about topic exact keyword match" do
    result = execute("talk to innkeeper about town")

    assert result[:success]
    assert_includes result[:response], "The town's been quiet"
  end

  # ─── LEADS_TO ──────────────────────────────────────────────────────────────

  test "leads to unlocks subtopic" do
    # First talk about town to unlock mine
    execute("talk to innkeeper about town")
    # Then talk about mine
    result = execute("talk to innkeeper about mine")

    assert result[:success]
    assert_includes result[:response], "Nobody's been down there"
  end

  test "subtopic locked before parent accessed" do
    result = execute("talk to innkeeper about mine")

    assert result[:success]
    assert_includes result[:response], "I'm not sure what you mean."
  end

  test "subtopic locked returns default when no locked text" do
    # Create a world where a locked subtopic has no locked_text
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => {
          "name" => "Room", "description" => "A room.", "exits" => {},
          "npcs" => ["npc1"]
        }
      },
      npcs: {
        "npc1" => {
          "name" => "Sage",
          "keywords" => ["sage"],
          "dialogue" => {
            "greeting" => "Greetings.",
            "default" => "I have nothing to say about that.",
            "topics" => {
              "lore" => {
                "keywords" => ["lore"],
                "text" => "Ancient lore speaks of...",
                "leads_to" => ["secret"]
              },
              "secret" => {
                "keywords" => ["secret"],
                "text" => "The secret is..."
              }
            }
          }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    # Try to access locked subtopic without locked_text
    command = ClassicGame::CommandParser.parse("talk to sage about secret")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert result[:success]
    assert_includes result[:response], "I have nothing to say about that."
  end

  # ─── REQUIRES FLAG ────────────────────────────────────────────────────────

  test "requires flag returns locked text when flag not set" do
    result = execute("talk to innkeeper about reward")

    assert result[:success]
    assert_includes result[:response], "Bring me proof the rats are gone first."
  end

  test "requires flag returns text when flag set" do
    @game.set_flag("rats_cleared", true)
    result = execute("talk to innkeeper about reward")

    assert result[:success]
    assert_includes result[:response], "You did it!"
  end

  # ─── REQUIRES ITEM ────────────────────────────────────────────────────────

  test "requires item returns locked text when item not in inventory" do
    result = execute("talk to innkeeper about appraisal")

    assert result[:success]
    assert_includes result[:response], "Bring me something worth appraising."
  end

  test "requires item returns text when item in inventory" do
    @game.game_state["player_states"][USER_ID.to_s] = player_state_in("tavern", inventory: ["sword"])
    result = execute("talk to innkeeper about appraisal")

    assert result[:success]
    assert_includes result[:response], "Fine craftsmanship."
  end

  # ─── SETS FLAG ─────────────────────────────────────────────────────────────

  test "sets flag is set when topic accessed" do
    execute("talk to innkeeper about work")

    assert @game.get_flag("rat_quest_started")
  end

  # ─── DEFAULT RESPONSE ─────────────────────────────────────────────────────

  test "no keyword match returns doesn't know message" do
    result = execute("talk to innkeeper about dragons")

    assert_not result[:success]
    assert_includes result[:response], "doesn't know anything about that."
  end

  # ─── NPC WITH NO DIALOGUE ─────────────────────────────────────────────────

  test "npc with no dialogue shows not interested" do
    result = execute("talk to guard")

    assert_not result[:success]
    assert_includes result[:response], "Guard doesn't seem interested in talking."
  end

  # ─── NPC WITH DIALOGUE BUT NO TOPICS ──────────────────────────────────────

  test "npc with dialogue but no topics returns greeting only" do
    result = execute("talk to greeter")

    assert result[:success]
    assert_includes result[:response], "Hello."
  end

  test "npc with dialogue but no topics returns error for topic query" do
    result = execute("talk to greeter about anything")

    assert_not result[:success]
    assert_includes result[:response], "doesn't know anything about that"
  end

  # ─── EDGE CASES ────────────────────────────────────────────────────────────

  test "talk to npc not in room fails" do
    world = build_world(
      starting_room: "empty_room",
      rooms: {
        "empty_room" => {
          "name" => "Empty Room", "description" => "Nothing here.", "exits" => {},
          "npcs" => []
        }
      },
      npcs: {
        "innkeeper" => {
          "name" => "Innkeeper",
          "keywords" => ["innkeeper"],
          "dialogue" => { "greeting" => "Hi." }
        }
      }
    )
    game = build_game(world_data: world, player_id: USER_ID)

    command = ClassicGame::CommandParser.parse("talk to innkeeper")
    result = ClassicGame::Handlers::InteractHandler.new(game: game, user_id: USER_ID).handle(command)

    assert_not result[:success]
    assert_includes result[:response].downcase, "don't see anyone"
  end

  test "talk with no target fails" do
    result = execute("talk")

    assert_not result[:success]
    assert_includes result[:response], "Talk to whom?"
  end

  private

    def execute(input)
      command = ClassicGame::CommandParser.parse(input)
      ClassicGame::Handlers::InteractHandler.new(game: @game, user_id: USER_ID).handle(command)
    end
end
