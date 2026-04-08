# frozen_string_literal: true

require "test_helper"

# End-to-end playthrough covering every ClassicGame mechanic with a purpose-built
# in-memory world (FakeGame, no database).  All randomness is stubbed so the
# results are deterministic across every CI run.
class FullGameSystemTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  USER_ID = 1

  # ─── FULL GAME PLAYTHROUGH ────────────────────────────────────────────────

  test "full game playthrough exercises every mechanic" do
    game = build_game(world_data: full_game_world)

    phase_examine_items(game)
    phase_movement_basic(game)
    phase_creature_talk(game)
    phase_travel_to_tavern(game)
    phase_dialogue(game)
    phase_containers(game)
    phase_npc_exchange(game)
    phase_flag_locked_movement(game)
    phase_travel_to_cave(game)
    phase_combat(game)
    phase_post_combat(game)
    phase_unknown_command(game)
  end

  # ─── FOCUSED: FLAG-LOCKED MOVEMENT ───────────────────────────────────────

  test "movement blocked by missing flag" do
    game = build_game(world_data: full_game_world,
                      player_state: player_state_in("tavern"))
    result = cmd(game, "go northwest")
    assert_not result[:success], "FLAG LOCK: should be blocked without innkeeper_trust"
    assert_includes result[:response], "won't budge", "FLAG LOCK: wrong locked message"
  end

  # ─── FOCUSED: PLAYER DEATH ───────────────────────────────────────────────

  test "combat player death shows game over" do
    world = build_world(
      starting_room: "arena",
      rooms: { "arena" => { "name" => "Arena", "description" => "A fighting pit.",
                            "exits" => {}, "creatures" => ["beast"] } },
      creatures: { "beast" => { "name" => "Lethal Beast", "keywords" => ["beast"],
                                "hostile" => false, "health" => 100,
                                "attack" => 100, "defense" => 0 } }
    )
    game = build_game(world_data: world)
    midpoint = ->(range) { range.is_a?(Range) ? (range.min + range.max) / 2 : 0 }
    Object.stub(:rand, midpoint) do
      cmd(game, "attack beast")
      result = cmd(game, "attack")
      assert_includes result[:response], "GAME OVER", "DEATH: game over message missing"
    end
  end

  # ─── FOCUSED: FLEE FAILURE ───────────────────────────────────────────────

  test "combat flee fails when rand is high" do
    world = build_world(
      starting_room: "room1",
      rooms: { "room1" => { "name" => "Room", "description" => "A room.",
                            "exits" => {}, "creatures" => ["troll"] } },
      creatures: { "troll" => { "name" => "Troll", "keywords" => ["troll"],
                                "hostile" => false, "health" => 30,
                                "attack" => 2, "defense" => 0 } }
    )
    game = build_game(world_data: world)
    midpoint = ->(range) { range.is_a?(Range) ? (range.min + range.max) / 2 : 0 }
    Object.stub(:rand, midpoint) { cmd(game, "attack troll") }
    flee_rand = ->(range) { range == (1..100) ? 75 : 0 }
    Object.stub(:rand, flee_rand) do
      result = cmd(game, "flee")
      assert result[:success], "FLEE FAIL: player should survive a failed flee"
      assert_includes result[:response], "blocks your escape", "FLEE FAIL: wrong message"
    end
  end

  # ─── FOCUSED: DICE ROLL FAILURE ──────────────────────────────────────────

  test "dice roll failure branch executes on_failure" do
    game = build_game(world_data: full_game_world,
                      player_state: player_state_in("cave", inventory: ["lockpick"]))
    cmd(game, "use lockpick")
    Object.stub(:rand, ->(range) { range.is_a?(Range) ? range.min : 0 }) do
      result = cmd(game, "roll")
      assert result[:success], "ROLL FAIL: expected success result even on dice failure"
      assert_includes result[:response], "Failed.", "ROLL FAIL: not in failure branch"
      assert_includes result[:response], "The pick slips.", "ROLL FAIL: wrong failure message"
    end
    assert game.get_flag("lock_jammed"), "ROLL FAIL: lock_jammed flag not set"
  end

  # ─── FOCUSED: AGGRESSIVE CREATURE THRESHOLD ──────────────────────────────

  test "aggressive creature attacks after threshold" do
    world = build_world(
      starting_room: "lair",
      rooms: { "lair" => { "name" => "Lair", "description" => "A dark lair.",
                           "exits" => {}, "creatures" => ["spider"] } },
      creatures: { "spider" => { "name" => "Spider", "keywords" => ["spider"],
                                 "hostile" => true, "health" => 10,
                                 "attack" => 1, "defense" => 0,
                                 "attack_condition" => { "moves" => 3 } } }
    )
    game = build_game(world_data: world)
    midpoint = ->(range) { range.is_a?(Range) ? (range.min + range.max) / 2 : 0 }
    Object.stub(:rand, midpoint) do
      cmd(game, "look")
      cmd(game, "look")
      result = cmd(game, "look")
      assert_includes result[:response].downcase, "attacks you",
                      "AGGRO: spider should attack at threshold (3 moves)"
    end
  end

  private

    # Short wrapper so phase methods stay readable.
    def cmd(game, text)
      execute_engine_command(game, USER_ID, text)
    end

    # ─── PHASE: LOOK / HELP / EXAMINE / TAKE / INVENTORY / DROP ─────────────

    def phase_examine_items(game)
      r = cmd(game, "look")
      assert r[:success], "LOOK: initial look failed"
      assert_includes r[:response], "Entrance", "LOOK: room name not in response"
      assert_includes r[:response], "Iron Key", "LOOK: iron_key not listed"

      r = cmd(game, "help")
      assert r[:success], "HELP: help command failed"
      assert_includes r[:response].downcase, "movement", "HELP: movement section missing"

      r = cmd(game, "examine iron key")
      assert r[:success], "EXAMINE: examine iron key failed"
      assert_includes r[:response].downcase, "iron", "EXAMINE: description missing"

      r = cmd(game, "take iron key")
      assert r[:success], "TAKE: take iron key failed"

      r = cmd(game, "inventory")
      assert r[:success], "INVENTORY: inventory failed"
      assert_includes r[:response], "Iron Key", "INVENTORY: iron_key not listed"

      r = cmd(game, "drop iron key")
      assert r[:success], "DROP: drop iron key failed"
      assert_includes r[:response].downcase, "drop", "DROP: confirmation missing"

      r = cmd(game, "take iron key")
      assert r[:success], "TAKE (re-take): re-take iron key failed"

      r = cmd(game, "take health potion")
      assert r[:success], "TAKE POTION: take health potion failed"
    end

    # ─── PHASE: SIMPLE MOVEMENT + SHORTHAND ──────────────────────────────────

    def phase_movement_basic(game)
      r = cmd(game, "go north")
      assert r[:success], "MOVE NORTH: go north to armory failed"
      assert_includes r[:response], "Armory", "MOVE NORTH: not in armory"

      r = cmd(game, "take wooden shield")
      assert r[:success], "TAKE SHIELD: take wooden shield failed"

      r = cmd(game, "s")
      assert r[:success], "MOVE S: shorthand south failed"
      assert_includes r[:response], "Entrance", "MOVE S: not back in entrance"
    end

    # ─── PHASE: NON-HOSTILE CREATURE TALK ────────────────────────────────────

    def phase_creature_talk(game)
      r = cmd(game, "talk to rat")
      assert r[:success], "TALK RAT: talk to friendly rat failed"
      assert_includes r[:response], "squeaks", "TALK RAT: talk_text not returned"
    end

    # ─── PHASE: TRAVEL TO TAVERN ─────────────────────────────────────────────

    def phase_travel_to_tavern(game)
      r = cmd(game, "go east")
      assert r[:success], "TRAVEL TAVERN: go east to tavern failed"
      assert_includes r[:response], "Tavern", "TRAVEL TAVERN: not in tavern"
    end

    # ─── PHASE: NPC DIALOGUE (GREETING / TOPICS / LEADS_TO / REQUIRES_FLAG) ──

    def phase_dialogue(game)
      r = cmd(game, "talk to innkeeper")
      assert r[:success], "DIALOGUE GREETING: talk to innkeeper failed"
      assert_includes r[:response], "Welcome", "DIALOGUE GREETING: greeting not shown"

      # requires_flag locked (innkeeper_trust not yet set)
      r = cmd(game, "talk to innkeeper about goblin threat")
      assert r[:success], "DIALOGUE RF LOCKED: call should succeed with locked_text"
      assert_includes r[:response], "haven't earned", "DIALOGUE RF LOCKED: wrong locked_text"

      # leads_to locked (stay topic not yet accessed)
      r = cmd(game, "talk to innkeeper about rumor")
      assert r[:success], "DIALOGUE LT LOCKED: call should succeed with locked_text"
      assert_includes r[:response], "don't know", "DIALOGUE LT LOCKED: wrong locked_text"

      # access leads_to parent → unlocks "rumor" topic
      r = cmd(game, "talk to innkeeper about stay")
      assert r[:success], "DIALOGUE LEADS_TO PARENT: failed"
      assert_includes r[:response], "goblin", "DIALOGUE LEADS_TO PARENT: text missing"
      assert_includes r[:response], "rumor", "DIALOGUE LEADS_TO PARENT: leads_to hint missing"

      # leads_to child now unlocked → sets innkeeper_trust flag
      r = cmd(game, "talk to innkeeper about rumor")
      assert r[:success], "DIALOGUE LEADS_TO CHILD: failed"
      assert_includes r[:response], "northwest", "DIALOGUE LEADS_TO CHILD: text missing"
      assert game.get_flag("innkeeper_trust"), "DIALOGUE LEADS_TO CHILD: innkeeper_trust not set"

      # requires_flag now satisfied
      r = cmd(game, "talk to innkeeper about goblin threat")
      assert r[:success], "DIALOGUE RF UNLOCKED: failed"
      assert_includes r[:response], "terrorizing", "DIALOGUE RF UNLOCKED: text missing"
    end

    # ─── PHASE: CONTAINER (LOCKED / OPEN / TAKE / CLOSE / EXAMINE) ───────────

    def phase_containers(game)
      r = cmd(game, "drop iron key")
      assert r[:success], "DROP KEY: failed before container test"

      r = cmd(game, "open chest")
      assert_not r[:success], "CONTAINER LOCKED: open should fail without key"
      assert_includes r[:response].downcase, "locked", "CONTAINER LOCKED: wrong message"

      r = cmd(game, "take iron key")
      assert r[:success], "TAKE KEY BACK: failed"

      r = cmd(game, "open chest")
      assert r[:success], "CONTAINER OPEN: open chest with key failed"
      assert_includes r[:response], "Gold Coin", "CONTAINER OPEN: contents not listed"

      r = cmd(game, "take gold coin")
      assert r[:success], "CONTAINER TAKE: take gold coin from chest failed"
      assert_includes game.player_state(USER_ID)["inventory"], "gold_coin",
                      "CONTAINER TAKE: gold_coin not in inventory"

      r = cmd(game, "close chest")
      assert r[:success], "CONTAINER CLOSE: close chest failed"

      r = cmd(game, "examine chest")
      assert r[:success], "CONTAINER EXAMINE CLOSED: failed"
      assert_includes r[:response].downcase, "closed", "CONTAINER EXAMINE CLOSED: wrong state"
    end

    # ─── PHASE: NPC ITEM EXCHANGE ─────────────────────────────────────────────

    def phase_npc_exchange(game)
      r = cmd(game, "give gold coin to merchant")
      assert r[:success], "GIVE: give gold coin to merchant failed"
      assert_includes r[:response].downcase, "gold coin", "GIVE: accept message missing"
      assert_includes game.player_state(USER_ID)["inventory"], "reward_gem",
                      "GIVE: reward_gem not received"
      assert_not_includes game.player_state(USER_ID)["inventory"], "gold_coin",
                          "GIVE: gold_coin not removed from inventory"
    end

    # ─── PHASE: FLAG-LOCKED EXIT (SUCCESS AFTER FLAG SET) ────────────────────

    def phase_flag_locked_movement(game)
      r = cmd(game, "go northwest")
      assert r[:success], "FLAG MOVE: go northwest failed (innkeeper_trust should be set)"
      assert_includes r[:response], "Secret Chamber", "FLAG MOVE: not in secret chamber"

      r = cmd(game, "go southeast")
      assert r[:success], "FLAG MOVE RETURN: go southeast back to tavern failed"
      assert_includes r[:response], "Tavern", "FLAG MOVE RETURN: not back in tavern"
    end

    # ─── PHASE: TRAVEL TO CAVE (ITEM-LOCKED EXIT) ─────────────────────────────

    def phase_travel_to_cave(game)
      cmd(game, "go west")

      r = cmd(game, "go north")
      assert r[:success], "TRAVEL CAVE: go north to armory failed"

      r = cmd(game, "go west")
      assert_not r[:success], "ITEM LOCK: go west (cave) should fail without using key"
      assert_includes r[:response].downcase, "sealed", "ITEM LOCK: wrong locked message"

      r = cmd(game, "use iron key on west")
      assert r[:success], "ITEM UNLOCK: use iron key on west failed"
      assert_includes r[:response].downcase, "gate", "ITEM UNLOCK: wrong unlock message"

      r = cmd(game, "go west")
      assert r[:success], "TRAVEL CAVE: go west to cave after unlock failed"
      assert_includes r[:response], "Cave", "TRAVEL CAVE: not in cave"
    end

    # ─── PHASE: COMBAT (INITIATE / ATTACK / DEFEND / HEAL / DEFEAT) ──────────

    def phase_combat(game)
      r = cmd(game, "take lockpick")
      assert r[:success], "TAKE LOCKPICK: failed"

      combat_rand = ->(range) {
        case range
        when(-2..2) then 0
        when(1..20) then 10
        when(1..100) then 25
        else range.is_a?(Range) ? range.min : 0
        end
      }
      Object.stub(:rand, combat_rand) do
        r = cmd(game, "attack goblin")
        assert r[:success], "COMBAT INIT: attack goblin failed"
        assert game.player_state(USER_ID).dig("combat", "active"),
               "COMBAT INIT: combat not active after attack"

        r = cmd(game, "attack")
        assert r[:success], "COMBAT ATK 1: attack in combat failed"
        assert_includes r[:response].downcase, "strike", "COMBAT ATK 1: strike message missing"

        r = cmd(game, "defend")
        assert r[:success], "COMBAT DEFEND: defend failed"
        assert_includes r[:response].downcase, "guard", "COMBAT DEFEND: guard message missing"

        r = cmd(game, "use health potion")
        assert r[:success], "COMBAT POTION: use health potion in combat failed"
        assert_includes r[:response].downcase, "recover", "COMBAT POTION: recover message missing"

        cmd(game, "attack")
        cmd(game, "attack")
        r = cmd(game, "attack")
        assert r[:success], "COMBAT FINAL: final attack failed"
        assert_includes r[:response].downcase, "collapses", "COMBAT FINAL: defeat message missing"
      end

      assert_nil game.player_state(USER_ID).dig("combat", "active"),
                 "COMBAT: combat still active after creature defeated"
      assert_includes game.room_state("cave")["items"], "old_sword",
                      "COMBAT LOOT: old_sword not dropped in cave"
      assert_not_includes game.room_state("cave")["creatures"], "goblin",
                          "COMBAT: goblin still listed in cave creatures"
      assert game.get_flag("goblin_slain"), "COMBAT FLAG: goblin_slain flag not set"
      assert game.exit_revealed?("cave", "south"),
             "COMBAT HIDDEN: south exit not revealed on goblin defeat"
    end

    # ─── PHASE: POST-COMBAT (DICE ROLL / HIDDEN EXIT / EXAMINE REVEALS EXIT) ──

    def phase_post_combat(game)
      r = cmd(game, "use lockpick")
      assert r[:success], "DICE TRIGGER: use lockpick failed"
      assert_includes r[:response], "ROLL", "DICE TRIGGER: roll prompt missing"
      assert game.player_state(USER_ID)["pending_roll"], "DICE TRIGGER: pending_roll not set"

      r = cmd(game, "look")
      assert_not r[:success], "DICE PENDING BLOCK: non-roll command should fail while roll pending"
      assert_includes r[:response], "ROLL", "DICE PENDING BLOCK: prompt message missing"

      Object.stub(:rand, ->(range) { range.is_a?(Range) ? range.max : 0 }) do
        r = cmd(game, "roll")
        assert r[:success], "DICE ROLL: roll command failed"
        assert_includes r[:response], "Success!", "DICE ROLL: not in success branch"
        assert_includes r[:response], "The lock clicks!", "DICE ROLL: success message missing"
      end
      assert_nil game.player_state(USER_ID)["pending_roll"],
                 "DICE ROLL: pending_roll not cleared after resolve"
      assert game.get_flag("north_lock_picked"), "DICE ROLL: success flag not set"

      r = cmd(game, "go south")
      assert r[:success], "HIDDEN EXIT: go south to treasury failed"
      assert_includes r[:response], "Treasury", "HIDDEN EXIT: not in treasury"

      r = cmd(game, "examine scroll")
      assert r[:success], "EXAMINE REVEALS: examine scroll failed"
      assert_includes r[:response].downcase, "east", "EXAMINE REVEALS: east mention missing"
      assert game.exit_revealed?("treasury", "east"),
             "EXAMINE REVEALS: east exit not revealed by scroll"
    end

    # ─── PHASE: UNKNOWN COMMAND ───────────────────────────────────────────────

    def phase_unknown_command(game)
      r = cmd(game, "xyzzy foo bar")
      assert_not r[:success], "UNKNOWN: unknown command should fail"
      assert_includes r[:response].downcase, "don't understand",
                      "UNKNOWN: wrong response for unknown command"
    end

    # ─── WORLD DEFINITION ────────────────────────────────────────────────────

    def full_game_world
      build_world(
        starting_room: "entrance",
        rooms: world_rooms,
        items: world_items,
        npcs: world_npcs,
        creatures: world_creatures
      )
    end

    def world_rooms # rubocop:disable Metrics/MethodLength
      {
        "entrance" => { "name" => "Entrance Hall", "description" => "A dimly lit entrance hall.",
                        "items" => ["iron_key", "health_potion"], "creatures" => ["friendly_rat"],
                        "exits" => { "north" => "armory", "east" => "tavern" } },
        "armory" => { "name" => "Armory", "description" => "Racks of dusty weapons line the walls.",
                      "items" => ["wooden_shield"],
                      "exits" => { "south" => "entrance", "west" => {
                        "to" => "cave", "use_item" => "iron_key", "permanently_unlock" => true,
                        "consume_item" => false, "locked_msg" => "The iron gate is sealed tight.",
                        "on_unlock" => "You use the iron key. The gate swings open."
                      } } },
        "tavern" => { "name" => "Rusty Flagon Tavern", "description" => "A cozy tavern with a fire.",
                      "items" => ["treasure_chest"], "npcs" => ["innkeeper", "merchant"],
                      "exits" => { "west" => "entrance", "northwest" => {
                        "to" => "secret_chamber", "requires_flag" => "innkeeper_trust",
                        "locked_msg" => "A heavy door. It won't budge."
                      } } },
        "cave" => { "name" => "Dark Cave", "description" => "A cold, damp cave.",
                    "items" => ["lockpick"], "creatures" => ["goblin"],
                    "exits" => { "east" => "armory", "south" => {
                      "to" => "treasury", "hidden" => true, "requires_flag" => "goblin_slain",
                      "reveal_msg" => "A dark passage to the south opens up!"
                    } } },
        "treasury" => { "name" => "Treasury", "description" => "A damp chamber with stone walls.",
                        "items" => ["ancient_scroll"],
                        "exits" => { "north" => "cave", "east" => {
                          "to" => "secret_chamber", "hidden" => true,
                          "reveal_msg" => "An ancient passage opens to the east!"
                        } } },
        "secret_chamber" => { "name" => "Secret Chamber",
                              "description" => "A hidden chamber with ancient artifacts.",
                              "exits" => { "southeast" => "tavern", "west" => "treasury" } }
      }
    end

    def world_items # rubocop:disable Metrics/MethodLength
      {
        "iron_key" => { "name" => "Iron Key", "keywords" => ["key", "iron"],
                        "takeable" => true, "description" => "A heavy iron key." },
        "health_potion" => { "name" => "Health Potion", "keywords" => ["potion", "health"],
                             "takeable" => true, "consumable" => true,
                             "combat_effect" => { "type" => "heal", "amount" => 5 },
                             "description" => "A red bubbling potion." },
        "wooden_shield" => { "name" => "Wooden Shield", "keywords" => ["shield", "wooden"],
                             "takeable" => true, "defense_bonus" => 3,
                             "description" => "A sturdy wooden shield." },
        "lockpick" => { "name" => "Lockpick", "keywords" => ["lockpick", "pick"],
                        "takeable" => true,
                        "dice_roll" => {
                          "dc" => 12, "dice" => "1d20",
                          "attempt_message" => "You carefully work the lockpick...",
                          "on_success" => { "sets_flag" => "north_lock_picked",
                                            "message" => "The lock clicks!" },
                          "on_failure" => { "sets_flag" => "lock_jammed",
                                            "message" => "The pick slips." },
                          "consume_on" => "failure"
                        } },
        "treasure_chest" => { "name" => "Treasure Chest", "keywords" => ["chest", "treasure"],
                              "is_container" => true, "starts_closed" => true, "locked" => true,
                              "unlock_item" => "iron_key", "contents" => ["gold_coin"],
                              "closed_description" => "A closed wooden chest.",
                              "open_description" => "An open wooden chest.",
                              "locked_message" => "The chest is locked. You need a key.",
                              "on_open_message" => "You unlock and open the chest." },
        "gold_coin" => { "name" => "Gold Coin", "keywords" => ["coin", "gold"],
                         "takeable" => true, "description" => "A shiny gold coin." },
        "ancient_scroll" => { "name" => "Ancient Scroll", "keywords" => ["scroll", "ancient"],
                              "takeable" => false, "description" => "An old weathered scroll.",
                              "on_examine" => { "reveals_exit" => "east",
                                                "text" => "The scroll reveals a passage to the east!" } },
        "old_sword" => { "name" => "Old Sword", "keywords" => ["sword", "old"],
                         "takeable" => true, "weapon_damage" => 8,
                         "description" => "A battered but effective sword." },
        "reward_gem" => { "name" => "Sparkling Gem", "keywords" => ["gem", "sparkling"],
                          "takeable" => true, "description" => "A beautiful gemstone." }
      }
    end

    def world_npcs
      {
        "innkeeper" => {
          "name" => "Innkeeper", "keywords" => ["innkeeper", "barkeeper", "inn"],
          "description" => "A stout innkeeper with a friendly smile.",
          "dialogue" => {
            "greeting" => "Welcome to the Rusty Flagon! What can I do for you?",
            "default" => "I don't know what you mean.",
            "topics" => {
              "stay" => { "keywords" => ["stay", "room", "welcome"],
                          "text" => "Business has been rough since the goblin moved into the cave.",
                          "leads_to" => ["rumor"] },
              "rumor" => { "keywords" => ["rumor", "secret", "chamber"],
                           "text" => "There is a hidden chamber to the northwest. I'll trust you.",
                           "locked_text" => "I don't know any secrets.",
                           "sets_flag" => "innkeeper_trust" },
              "goblin_threat" => { "keywords" => ["threat", "danger", "goblin"],
                                   "text" => "The goblin has been terrorizing travelers for years.",
                                   "locked_text" => "You haven't earned my trust yet.",
                                   "requires_flag" => "innkeeper_trust" }
            }
          }
        },
        "merchant" => {
          "name" => "Merchant", "keywords" => ["merchant", "trader", "shop"],
          "description" => "A shifty-eyed merchant with a large pack.",
          "accepts_item" => "gold_coin", "gives_item" => "reward_gem",
          "accept_message" => "A gold coin! Just what I wanted.",
          "sets_flag" => "trade_complete"
        }
      }
    end

    def world_creatures
      {
        "goblin" => {
          "name" => "Goblin", "keywords" => ["goblin"],
          "hostile" => true, "health" => 20, "attack" => 2, "defense" => 0,
          "talk_text" => "The goblin snarls and waves its fist.",
          "attack_condition" => { "moves" => 3 },
          "loot" => ["old_sword"], "sets_flag_on_defeat" => "goblin_slain",
          "on_defeat_msg" => "The goblin collapses with a screech!"
        },
        "friendly_rat" => {
          "name" => "Friendly Rat", "keywords" => ["rat", "friendly"],
          "hostile" => false, "health" => 3, "attack" => 1, "defense" => 0,
          "talk_text" => "The rat squeaks and sniffs at you curiously."
        }
      }
    end
end
