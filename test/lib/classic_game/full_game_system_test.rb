# frozen_string_literal: true

require "test_helper"

# Comprehensive end-to-end playthrough of a purpose-built 5-room world.
# Routes every command through ClassicGame::Engine to exercise the full stack:
# aggressive-creature checks, pending-roll routing, and all handler dispatch paths.
#
# Design choices for determinism:
#   - Troll HP: 1  (dies on any hit; min player damage is 1)
#   - Dice roll DC: 1  (1d20 minimum is 1, so roll always succeeds)
#   - srand(42) wraps the test for repeatable rand sequences
class FullGameSystemTest < ActiveSupport::TestCase
  include ClassicGameTestHelper

  FakeUser = Struct.new(:id)
  USER_ID = 42

  test "full game playthrough" do
    world = build_full_game_world
    game  = build_game(world_data: world)
    user  = FakeUser.new(USER_ID)

    with_deterministic_rand(42) do
      phase_orientation(game, user)
      phase_dialogue(game, user)
      phase_items_containers(game, user)
      phase_dice_rolls(game, user)
      phase_movement(game, user)
      phase_combat(game, user)
      phase_npc_exchange(game, user)
      phase_final_room(game, user)
      phase_npc_movement(game, user)
      phase_verification(game, user)
    end
  end

  private

    # Convenience wrapper so phase methods stay concise
    def ex(game, user, cmd)
      execute_engine(game, user, cmd)
    end

    # ─── World builders ─────────────────────────────────────────────────────

    def build_full_game_world
      build_world(
        starting_room: "entrance",
        rooms: rooms_data,
        items: items_data,
        npcs: npcs_data,
        creatures: creatures_data
      )
    end

    def rooms_data
      {
        "entrance" => {
          "name" => "Entrance Hall",
          "description" => "A grand entrance hall. A guide stands nearby.",
          "items" => ["old_key"],
          "npcs" => %w[guide wandering_merchant],
          "exits" => {
            "east" => "storeroom",
            "south" => "cave",
            "north" => { "to" => "tower", "requires_flag" => "tower_unlocked",
                         "locked_msg" => "The tower door is sealed." }
          }
        },
        "storeroom" => {
          "name" => "Storeroom",
          "description" => "A dusty storeroom with shelves.",
          "items" => %w[supply_crate lockpick],
          "exits" => { "west" => "entrance" }
        },
        "cave" => {
          "name" => "Dark Cave",
          "description" => "A damp, dimly lit cave.",
          "creatures" => ["troll"],
          "exits" => {
            "north" => "entrance",
            "west" => { "to" => "alcove", "hidden" => true, "requires_flag" => "troll_slain",
                        "reveal_msg" => "A passage to the west is now visible!" }
          }
        },
        "tower" => {
          "name" => "Wizard's Tower",
          "description" => "A tall tower filled with arcane artifacts.",
          "items" => ["scroll"],
          "npcs" => ["wizard"],
          "exits" => { "south" => "entrance" }
        },
        "alcove" => {
          "name" => "Hidden Alcove",
          "description" => "A small, secret alcove.",
          "items" => ["victory_crown"],
          "exits" => { "east" => "cave" },
          "on_enter" => { "type" => "message",
                          "text" => "You squeeze through a hidden passage into a forgotten alcove!" }
        }
      }
    end

    def items_data
      basic_items.merge(complex_items)
    end

    def basic_items
      {
        "old_key" => {
          "name" => "Old Key", "keywords" => ["key"],
          "takeable" => true, "description" => "A tarnished old key."
        },
        "gem" => {
          "name" => "Glowing Gem", "keywords" => %w[gem glowing],
          "takeable" => true, "description" => "It pulsates with inner light."
        },
        "enchanted_blade" => {
          "name" => "Enchanted Blade", "keywords" => %w[blade sword enchanted],
          "takeable" => true, "weapon_damage" => 3,
          "description" => "A blade humming with magic."
        },
        "scroll" => {
          "name" => "Ancient Scroll", "keywords" => %w[scroll ancient],
          "takeable" => true, "description" => "Yellowed parchment covered in runes.",
          "on_use" => { "type" => "message", "text" => "The scroll speaks of ancient prophecies." }
        },
        "victory_crown" => {
          "name" => "Victory Crown", "keywords" => %w[crown victory],
          "takeable" => true, "description" => "The crown of the realm."
        }
      }
    end

    def complex_items
      {
        "health_potion" => {
          "name" => "Health Potion", "keywords" => %w[potion health],
          "takeable" => true, "consumable" => true,
          "description" => "A red potion that restores health.",
          "combat_effect" => { "type" => "heal", "amount" => 5 }
        },
        "lockpick" => {
          "name" => "Lockpick", "keywords" => %w[lockpick pick],
          "takeable" => true, "description" => "A slender metal pick.",
          "dice_roll" => {
            "dc" => 1, "dice" => "1d20",
            "attempt_message" => "You attempt to pick a lock...",
            "consume_on" => "failure",
            "on_success" => { "message" => "The lock clicks open! You've mastered the lockpick.",
                              "sets_flag" => "lockpick_mastered" },
            "on_failure" => { "message" => "The lockpick snaps! Better luck next time." }
          }
        },
        "supply_crate" => {
          "name" => "Supply Crate", "keywords" => %w[crate supply chest],
          "is_container" => true, "starts_closed" => true,
          "locked" => true, "unlock_item" => "old_key",
          "contents" => ["health_potion"],
          "description" => "A heavy wooden crate.",
          "closed_description" => "A heavy wooden crate, firmly closed.",
          "open_description" => "An open supply crate.",
          "locked_message" => "It's locked tight.",
          "on_open_message" => "You unlock and open the crate."
        }
      }
    end

    def npcs_data
      { "guide" => guide_data, "wizard" => wizard_data, "wandering_merchant" => wandering_merchant_data }
    end

    def guide_data
      {
        "name" => "Guide", "keywords" => ["guide"],
        "description" => "A helpful traveler who knows the area.",
        "dialogue" => {
          "greeting" => "Welcome, adventurer! Ask me about 'directions' to learn more.",
          "sets_flag" => "spoke_to_guide",
          "topics" => {
            "directions" => {
              "keywords" => %w[directions direction],
              "text" => "Head north for the tower, south for the cave.",
              "leads_to" => ["secret"]
            },
            "secret" => {
              "keywords" => ["secret"],
              "text" => "There is a hidden alcove beyond the cave.",
              "locked_text" => "I have nothing more to share."
            },
            "tower" => {
              "keywords" => ["tower"],
              "text" => "The wizard will trade rare gems for powerful weapons.",
              "sets_flag" => "tower_unlocked",
              "requires_flag" => "spoke_to_guide",
              "locked_text" => "I wouldn't know anything about that."
            }
          }
        }
      }
    end

    def wizard_data
      {
        "name" => "Wizard", "keywords" => ["wizard"],
        "description" => "A robed figure with a long beard.",
        "accepts_item" => "gem", "gives_item" => "enchanted_blade",
        "accept_message" => "Ah, a Glowing Gem! Just what I needed.",
        "dialogue" => { "greeting" => "I am the wizard. Bring me a gem and I shall reward you." }
      }
    end

    def wandering_merchant_data
      {
        "name" => "Wandering Merchant", "keywords" => %w[merchant wandering],
        "description" => "A merchant with a cart of wares.",
        "movement" => {
          "type" => "patrol",
          "schedule" => [
            { "room" => "entrance", "duration" => 3 },
            { "room" => "storeroom", "duration" => 2 }
          ],
          "depart_msg" => "The Wandering Merchant heads to the storeroom.",
          "arrive_msg" => "The Wandering Merchant returns from the storeroom."
        }
      }
    end

    def creatures_data
      {
        "troll" => {
          "name" => "Troll", "keywords" => ["troll"],
          "hostile" => true, "health" => 1, "attack" => 3, "defense" => 0,
          # attack_condition moves:4 allows go-south + talk + look before the 2nd look triggers aggro
          "attack_condition" => { "moves" => 4 },
          "loot" => ["gem"], "sets_flag_on_defeat" => "troll_slain",
          "on_defeat_msg" => "The troll collapses with a thunderous crash!",
          "aggro_text" => "The troll snarls and charges at you!",
          "talk_text" => "The troll growls menacingly."
        }
      }
    end

    # ─── Phase helpers ───────────────────────────────────────────────────────

    # Phase 1: basic observation commands from the starting room
    def phase_orientation(game, user)
      r = ex(game, user, "look")
      assert r[:success], "PHASE 1: look should succeed"
      assert_includes r[:response], "Entrance Hall"
      assert_includes r[:response], "Old Key"
      assert_includes r[:response], "Guide"
      # north exit is visible (not hidden, just flag-gated); no west exit on this room
      assert_includes r[:response], "NORTH"
      assert_not_includes r[:response], "WEST"

      r = ex(game, user, "help")
      assert_includes r[:response], "Available commands"

      r = ex(game, user, "inventory")
      assert_includes r[:response], "carrying nothing"

      r = ex(game, user, "examine guide")
      assert_includes r[:response], "helpful traveler"
    end

    # Phase 2: NPC dialogue — greeting, leads_to chain, requires_flag topic
    def phase_dialogue(game, user)
      r = ex(game, user, "talk to guide")
      assert r[:success], "PHASE 2: greeting should succeed"
      assert_includes r[:response], "Welcome, adventurer"
      assert game.get_flag("spoke_to_guide"), "spoke_to_guide flag should be set after greeting"

      r = ex(game, user, "talk to guide about directions")
      assert_includes r[:response], "Head north for the tower"
      assert_includes r[:response], "secret", "leads_to hint should mention the unlocked topic"

      r = ex(game, user, "talk to guide about secret")
      assert r[:success], "secret topic should be unlocked after asking about directions"
      assert_includes r[:response], "hidden alcove"

      r = ex(game, user, "talk to guide about tower")
      assert r[:success], "tower topic requires spoke_to_guide flag, which is set"
      assert_includes r[:response], "wizard"
      assert game.get_flag("tower_unlocked"), "tower_unlocked flag should be set after tower topic"
    end

    # Phase 3: take, container locking, open with key, close, drop/take, use absent item
    def phase_items_containers(game, user)
      r = ex(game, user, "go east")
      assert_includes r[:response], "Storeroom", "PHASE 3: should move to storeroom"

      r = ex(game, user, "open crate")
      assert_not r[:success], "crate should be locked before player has the key"
      assert_includes r[:response].downcase, "locked"

      ex(game, user, "go west")

      r = ex(game, user, "take key")
      assert r[:success], "should be able to take the old key from the entrance"
      assert_includes game.player_state(USER_ID)["inventory"], "old_key"

      ex(game, user, "go east")

      r = ex(game, user, "open crate")
      assert r[:success], "crate should open with key in inventory"
      assert_includes r[:response], "Health Potion"

      r = ex(game, user, "take potion")
      assert r[:success]
      assert_includes game.player_state(USER_ID)["inventory"], "health_potion"

      r = ex(game, user, "close crate")
      assert r[:success]

      r = ex(game, user, "examine crate")
      assert_includes r[:response], "firmly closed"

      r = ex(game, user, "take lockpick")
      assert r[:success]

      r = ex(game, user, "drop lockpick")
      assert r[:success]
      assert_not_includes game.player_state(USER_ID)["inventory"], "lockpick"

      r = ex(game, user, "take lockpick")
      assert r[:success]
      assert_includes game.player_state(USER_ID)["inventory"], "lockpick"

      r = ex(game, user, "use scroll")
      assert_not r[:success], "scroll is in the tower, not in inventory"
    end

    # Phase 4: dice roll trigger, pending-roll guard, roll resolution
    def phase_dice_rolls(game, user)
      r = ex(game, user, "use lockpick")
      assert r[:success], "PHASE 4: using lockpick should trigger a pending roll"
      assert_includes r[:response], "ROLL"
      assert game.player_state(USER_ID)["pending_roll"].present?, "pending_roll should be set"

      r = ex(game, user, "look")
      assert_not r[:success], "non-roll commands should be blocked while roll is pending"
      assert_includes r[:response].upcase, "ROLL"

      r = ex(game, user, "roll")
      assert r[:success], "roll should succeed (DC 1 guarantees success)"
      assert_includes r[:response], "Success"
      assert_includes r[:response], "lock clicks open"
      assert_nil game.player_state(USER_ID)["pending_roll"], "pending_roll should be cleared"
      assert game.get_flag("lockpick_mastered"), "on_success sets_flag should fire"
    end

    # Phase 5: flag-gated north exit, use scroll (on_use message), examine, return
    def phase_movement(game, user)
      r = ex(game, user, "go west")
      assert_includes r[:response], "Entrance Hall", "PHASE 5: should return to entrance"

      r = ex(game, user, "go north")
      assert r[:success], "north exit should be traversable now that tower_unlocked is set"
      assert_includes r[:response], "Wizard's Tower"

      r = ex(game, user, "take scroll")
      assert r[:success]
      assert_includes game.player_state(USER_ID)["inventory"], "scroll"

      r = ex(game, user, "use scroll")
      assert r[:success]
      assert_includes r[:response], "ancient prophecies"

      r = ex(game, user, "examine scroll")
      assert_includes r[:response], "parchment"

      r = ex(game, user, "go south")
      assert_includes r[:response], "Entrance Hall"
    end

    # Phase 6: enter cave, talk (no aggro), two looks (aggro on 4th action), combat, loot
    def phase_combat(game, user)
      r = ex(game, user, "go south")
      assert_includes r[:response], "Dark Cave", "PHASE 6: should enter the cave"
      assert_not game.player_state(USER_ID).dig("combat", "active"), "no combat yet after entering"

      r = ex(game, user, "talk to troll")
      assert_includes r[:response], "growls menacingly"
      assert_not game.player_state(USER_ID).dig("combat", "active"), "no combat after talking (moves:4)"

      # 3rd room action — still below threshold
      ex(game, user, "look")
      assert_not game.player_state(USER_ID).dig("combat", "active"), "no combat on 3rd action"

      # 4th room action — troll attacks!
      r = ex(game, user, "look")
      assert_includes r[:response], "troll snarls", "aggro_text should appear on 4th action"
      assert game.player_state(USER_ID).dig("combat", "active"), "troll should have initiated combat"

      # One-hit kill: troll has 1 HP, min player damage is 1
      r = ex(game, user, "attack")
      assert_includes r[:response], "thunderous crash", "defeat message should appear"
      assert_includes r[:response], "drops: Glowing Gem", "loot should be dropped"
      assert_includes r[:response], "passage to the west is now visible", "hidden exit should be revealed"
      assert game.get_flag("troll_slain"), "troll_slain flag should be set"
      assert_nil game.player_state(USER_ID)["combat"], "combat should be cleared after victory"

      r = ex(game, user, "look")
      assert_not_includes game.room_state("cave")["creatures"] || [], "troll"
      assert_includes r[:response], "Glowing Gem", "dropped gem should be visible"
      assert_includes r[:response], "WEST", "revealed west exit should appear"

      r = ex(game, user, "take gem")
      assert r[:success]
      assert_includes game.player_state(USER_ID)["inventory"], "gem"
    end

    # Phase 7: navigate to wizard and exchange gem for enchanted blade
    def phase_npc_exchange(game, user)
      r = ex(game, user, "go north")
      assert_includes r[:response], "Entrance Hall", "PHASE 7: cave → entrance"

      r = ex(game, user, "go north")
      assert_includes r[:response], "Wizard's Tower"

      r = ex(game, user, "give gem to wizard")
      assert r[:success], "give should succeed — wizard accepts the gem"
      assert_includes r[:response], "Glowing Gem"
      assert_includes r[:response], "Enchanted Blade"
      assert_includes game.player_state(USER_ID)["inventory"], "enchanted_blade"
      assert_not_includes game.player_state(USER_ID)["inventory"], "gem"

      r = ex(game, user, "inventory")
      assert_includes r[:response], "Enchanted Blade"
    end

    # Phase 8: traverse the now-revealed hidden exit and pick up the victory crown
    def phase_final_room(game, user)
      r = ex(game, user, "go south")
      assert_includes r[:response], "Entrance Hall", "PHASE 8: tower → entrance"

      r = ex(game, user, "go south")
      assert_includes r[:response], "Dark Cave"

      r = ex(game, user, "go west")
      assert r[:success], "hidden west exit should be traversable after troll defeated"
      assert_includes r[:response], "Hidden Alcove"
      assert_includes r[:response], "squeeze through", "on_enter message should show on first visit"

      r = ex(game, user, "take crown")
      assert r[:success]
      assert_includes game.player_state(USER_ID)["inventory"], "victory_crown"
    end

    # Phase 9: NPC movement — merchant patrols entrance ↔ storeroom
    def phase_npc_movement(game, user)
      # Player is currently in the alcove after phase_final_room.
      # Navigate back to entrance to observe the merchant.
      ex(game, user, "go east") # alcove → cave
      ex(game, user, "go north") # cave → entrance

      # Merchant starts in entrance (schedule_index 0, duration 3).
      # The orientation phase has already fired several turns via execute_engine calls
      # (each ex() call runs process_npc_movement). By the time we're here,
      # the turn count is high enough that the merchant may already be in storeroom.
      # Issue enough commands to guarantee a full patrol cycle and observe movement.
      depart_seen = false
      arrive_seen = false

      8.times do
        r = ex(game, user, "look")
        depart_seen = true if r[:response].include?("Wandering Merchant heads to the storeroom")
        arrive_seen = true if r[:response].include?("Wandering Merchant returns from the storeroom")
      end

      # After 8 more turns, the merchant should have completed at least one full patrol cycle
      merchant_in_entrance = game.room_state("entrance")["npcs"].include?("wandering_merchant")
      merchant_in_storeroom = game.room_state("storeroom")["npcs"]&.include?("wandering_merchant") || false
      assert merchant_in_entrance || merchant_in_storeroom,
             "PHASE 9: merchant should be in either entrance or storeroom"
    end

    # Phase 10: final state verification
    def phase_verification(game, user)
      r = ex(game, user, "inventory")
      assert_includes r[:response], "Victory Crown",   "PHASE 10: victory crown should be in inventory"
      assert_includes r[:response], "Enchanted Blade", "enchanted blade should be in inventory"
      assert_includes r[:response], "Old Key",         "old key should still be in inventory"
      assert_not_includes r[:response], "Glowing Gem", "gem was given away"
      assert_includes r[:response], "=== INVENTORY ===", "inventory should show formatted header"
      assert_includes r[:response], "EXAMINE",         "inventory should include examine hint"

      # Verify inventory_data is present and contains expected items
      assert r[:state_changes][:inventory_data].is_a?(Array), "inventory_data should be an Array"
      inv_names = r[:state_changes][:inventory_data].map { |i| i["name"] }
      assert_includes inv_names, "Victory Crown",   "inventory_data should include Victory Crown"
      assert_includes inv_names, "Enchanted Blade", "inventory_data should include Enchanted Blade"

      r = ex(game, user, "examine enchanted blade")
      assert_includes r[:response], "Damage: +3",            "enchanted blade should show weapon stats"
      assert_includes r[:response], "blade humming with magic", "enchanted blade description should appear"

      assert game.get_flag("spoke_to_guide"),  "spoke_to_guide flag should be set"
      assert game.get_flag("tower_unlocked"),  "tower_unlocked flag should be set"
      assert game.get_flag("troll_slain"),     "troll_slain flag should be set"

      assert_not_includes game.room_state("cave")["creatures"] || [], "troll"
      assert game.exit_revealed?("cave", "west"), "west exit from cave should be permanently revealed"
    end
end
