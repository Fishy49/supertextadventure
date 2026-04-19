# frozen_string_literal: true

require "application_system_test_case"

# Full end-to-end browser playthrough of the QA Test World.
#
# Exercises every game mechanic through the actual UI — typing commands into the
# terminal input and verifying responses render on the page.
#
# Mechanics covered: look, help, inventory, examine, take, drop, use (consumable),
# open/close containers (key-locked), dice rolls (pending/blocking/resolution),
# NPC dialogue (greeting, flag-gated, item-gated, leads_to chains),
# creature interaction (hostile + friendly), combat (attack, defeat, loot),
# flag-gated navigation, hidden-exit reveal, NPC item exchange.
module QaWorld
  class FullPlaythroughTest < ApplicationSystemTestCase
    test "complete playthrough of QA world" do
      visit dev_game_path
      find(".terminal-input").click

      phase_orientation
      phase_item_basics
      phase_dialogue
      phase_containers
      phase_dice_roll
      phase_navigation
      phase_npc_exchange
      phase_consumable
      phase_combat
      phase_hidden_exit
      phase_final_verification
    end

    private

      def cmd(text)
        find(".terminal-input").send_keys(text, :return)
      end

      # Send a command and wait for new response messages to appear.
      # Use when the next assertion text already exists on the page,
      # or when no assertion follows and we just need to sync.
      def cmd_and_wait(text)
        count = all(".game-message", wait: false).count
        find(".terminal-input").send_keys(text, :return)
        assert_selector ".game-message", minimum: count + 2, wait: 10
      end

      # ─── Phase 1: Orientation ─────────────────────────────────────
      # Basic observation commands in the starting room.
      def phase_orientation
        assert_text "Town Square"

        cmd "look"
        assert_text "Town Crier"

        cmd "help"
        assert_text "Available commands"

        within("[id^='player_inventory_']") { assert_text "(empty)" }

        cmd "examine crier"
        assert_text "loud man"
      end

      # ─── Phase 2: Item Basics ─────────────────────────────────────
      # Take, examine, drop, retake — and verify via inventory.
      def phase_item_basics
        cmd "take key"
        assert_text "You take the Rusty Key"

        cmd "examine key"
        assert_text "rusty iron key"

        cmd "drop key"
        assert_text "You drop the Rusty Key"

        cmd_and_wait "take key"

        within("[id^='player_inventory_']") { assert_text "Rusty Key" }
      end

      # ─── Phase 3: Dialogue ────────────────────────────────────────
      # NPC conversations: greeting, flag-gated topics, item-gated topics,
      # leads_to chains, and friendly creature interaction.
      def phase_dialogue
        # Crier greeting sets spoke_to_crier flag
        cmd "talk to crier"
        assert_text "Hear ye"

        # Move to tavern for innkeeper dialogue
        cmd "go east"
        assert_text "The Tavern"

        # Innkeeper greeting
        cmd "talk to innkeeper"
        assert_text "Welcome to the tavern"

        # Flag-gated topic (requires spoke_to_crier) — sets tower_unlocked
        cmd "talk to innkeeper about tower"
        assert_text "tower can be unlocked"

        # Regular topic
        cmd "talk to innkeeper about rooms"
        assert_text "five main areas"

        # Item-gated topic (requires rusty_key in inventory)
        cmd "talk to innkeeper about supplies"
        assert_text "chest in the corner"

        # leads_to chain: rumors unlocks cellar subtopic
        cmd "talk to innkeeper about rumors"
        assert_text "lurking in the cellar"
        assert_text "You could ask about: cellar."

        cmd "talk to innkeeper about cellar"
        assert_text "cellar entrance"

        # Friendly creature interaction
        cmd "talk to rat"
        assert_text "squeaks"
      end

      # ─── Phase 4: Containers ──────────────────────────────────────
      # Open locked container with key, take contents, close.
      def phase_containers
        cmd "open chest"
        assert_text "unlock the chest"

        cmd "take potion"
        assert_text "You take the Health Potion"

        cmd "close chest"
        assert_text "You close the Wooden Chest"

        cmd "take lockpick"
        assert_text "You take the Lockpick"
      end

      # ─── Phase 5: Dice Roll ───────────────────────────────────────
      # Trigger pending roll, verify it blocks other commands, resolve.
      def phase_dice_roll
        cmd "use lockpick"
        assert_text "Type ROLL"

        # Non-roll commands are blocked while a roll is pending
        cmd "look"
        assert_text "You need to ROLL first"

        # Resolve the roll (outcome varies — DC 12 on d20)
        cmd "roll"
        assert_text(/Success!|Failed\./)
        assert_text "TOTAL:"
      end

      # ─── Phase 6: Navigation ──────────────────────────────────────
      # Flag-gated exit to tower (tower_unlocked set via dialogue).
      def phase_navigation
        cmd_and_wait "go west" # return to Town Square (text already on page)

        # North exit was locked; tower_unlocked flag was set by innkeeper
        cmd "go north"
        assert_text "Tower Top"
        assert_text "wind howls"

        cmd "take gem"
        assert_text "You take the Sparkling Gem"

        cmd "examine gem"
        assert_text "glows faintly"

        cmd_and_wait "go south" # return to Town Square
      end

      # ─── Phase 7: NPC Exchange ────────────────────────────────────
      # Give gem to merchant, receive enchanted sword.
      def phase_npc_exchange
        cmd "go west"
        assert_text "The Market"

        cmd "talk to merchant"
        assert_text "sparkling gem"

        cmd "give gem to merchant"
        assert_text "enchanted sword in return"

        cmd_and_wait "go east" # return to Town Square
      end

      # ─── Phase 8: Consumable ──────────────────────────────────────
      # Use health potion outside of combat.
      def phase_consumable
        cmd "use potion"
        assert_text "revitalized"
      end

      # ─── Phase 9: Combat ──────────────────────────────────────────
      # Fight cave spider to defeat; collect loot.
      def phase_combat
        cmd "go south"
        assert_text "The Cave"

        # Talk to hostile creature before fighting
        cmd "talk to spider"
        assert_text "hisses"

        # Initiate combat
        cmd "attack spider"
        assert_text "engage"

        # Fight until victory (player has 50 HP + enchanted sword; spider has 8 HP)
        10.times do
          cmd "attack"
          break if page.has_text?("crumples", wait: 2)
        end

        assert_text "crumples"
        assert_text "narrow passage"

        cmd "take shield"
        assert_text "You take the Iron Shield"
      end

      # ─── Phase 10: Hidden Exit ────────────────────────────────────
      # Traverse the exit revealed by defeating the cave spider.
      def phase_hidden_exit
        cmd "go east"
        assert_text "Secret Alcove"
        assert_text "crystals"

        cmd_and_wait "go west" # return to The Cave
      end

      # ─── Phase 11: Final Verification ─────────────────────────────
      # Return home and verify final inventory state.
      def phase_final_verification
        cmd_and_wait "go north" # return to Town Square

        within("[id^='player_inventory_']") do
          assert_text "Enchanted Sword"
          assert_text "Iron Shield"
        end
      end
  end
end
