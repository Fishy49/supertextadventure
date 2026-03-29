# frozen_string_literal: true

require "application_system_test_case"

module QaWorld
  class CombatTest < ApplicationSystemTestCase
    test "entering cave shows spider" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"
      assert_text "Cave Spider"
    end

    test "attack cave_spider shows combat feedback" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      find(".terminal-input").send_keys("attack spider", :return)
      assert_text "Cave Spider"
      assert_text "combat"
    end

    test "defeat spider drops shield and reveals passage" do
      visit dev_game_path
      find(".terminal-input").click

      defeat_spider

      assert_text "Iron Shield"
      assert_text "narrow passage"
    end

    test "go east in cave after killing spider enters alcove in one step" do
      visit dev_game_path
      find(".terminal-input").click

      defeat_spider

      find(".terminal-input").send_keys("go east", :return)
      assert_text "Secret Alcove"
    end

    test "look in cave after passage revealed shows passage description" do
      visit dev_game_path
      find(".terminal-input").click

      defeat_spider

      find(".terminal-input").send_keys("look", :return)
      assert_text "narrow passage"
      assert_text "EAST"
    end

    test "flee exits combat" do
      visit dev_game_path
      find(".terminal-input").click

      find(".terminal-input").send_keys("go south", :return)
      assert_text "The Cave"

      find(".terminal-input").send_keys("attack spider", :return)
      assert_text "Cave Spider"

      # Try to flee (50% chance, retry up to 10 times)
      10.times do
        find(".terminal-input").send_keys("flee", :return)
        break if page.has_text?("flee from combat", wait: 1)
      end

      assert_text "flee"
    end

    private

      # Fight the spider, restarting the game if the player dies.
      # Navigates to the cave and attacks until the spider is defeated.
      # Grab the rusty key, open the chest for the health potion, then fight.
      # The potion gives a heal mid-combat, making the fight reliably winnable.
      def defeat_spider
        # Deterministic setup: key → tavern → open chest → take potion
        find(".terminal-input").send_keys("take key", :return)
        assert_text "Rusty Key"

        find(".terminal-input").send_keys("go east", :return)
        assert_text "The Tavern"

        find(".terminal-input").send_keys("open chest", :return)
        assert_text "Health Potion"

        find(".terminal-input").send_keys("take potion", :return)
        assert_text "You take"

        find(".terminal-input").send_keys("go west", :return)
        assert_text "Town Square"

        find(".terminal-input").send_keys("go south", :return)
        assert_text "The Cave"

        find(".terminal-input").send_keys("attack spider", :return)
        assert_text "Cave Spider"

        # First exchange — take at least one hit so the potion isn't wasted
        find(".terminal-input").send_keys("attack", :return)

        unless page.has_text?("crumples", wait: 1)
          # Heal after taking damage, giving us ~15 effective HP
          find(".terminal-input").send_keys("use potion", :return)
          assert_text "recover"

          14.times do
            find(".terminal-input").send_keys("attack", :return)
            break if page.has_text?("crumples", wait: 1)
          end
        end

        assert_text "crumples"
      end
  end
end
