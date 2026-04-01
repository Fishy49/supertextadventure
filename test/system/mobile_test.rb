# frozen_string_literal: true

require_relative "../support/mobile_system_test_case"

class MobileTest < MobileSystemTestCase
  setup do
    @user = users(:player1)
  end

  test "login page renders on mobile" do
    visit root_path
    assert_text "SuperTextAdventure"
    assert_text "All Who Seek Adventure"
    assert_selector "input[name='username']"
  end

  test "tavern page is navigable on mobile" do
    sign_in_as(@user)
    visit tavern_path
    assert_text "Ye Olde Tavern"
    assert_link "Start a New Game"
  end

  test "game page has mobile nav on mobile" do
    sign_in_as(@user)
    visit dev_game_path
    # Mobile nav bar should be visible
    assert_selector "[data-controller='mobile-nav']"
    # Click hamburger to open nav drawer
    find("[data-action*='toggleDrawer']").click
    # Drawer should be open (translate-y-0)
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-0"
    within("[data-mobile-nav-target='drawer']") do
      assert_link "Tavern"
    end
  end

  test "game page desktop footer hidden on mobile" do
    sign_in_as(@user)
    visit dev_game_path
    # The footer has hidden md:grid — at mobile width it should be hidden
    assert_selector "footer.hidden", visible: false
    # Mobile nav is visible
    assert_selector "[data-controller='mobile-nav']", visible: true
  end

  test "game page mobile nav drawer toggles" do
    sign_in_as(@user)
    visit dev_game_path
    # Drawer should initially be off-screen (translate-y-full)
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-full"
    # Open it
    find("[data-action*='toggleDrawer']").click
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-0"
    within("[data-mobile-nav-target='drawer']") do
      assert_link "Tavern"
      assert_link "About"
      assert_link "Logout"
    end
    # Close it
    find("[data-action*='toggleDrawer']").click
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-full"
  end

  test "ascii art does not overflow on mobile" do
    visit root_path
    # ASCII wrapper should have overflow-x-auto to prevent layout breaking
    assert_selector "pre", visible: true
    assert_selector ".overflow-x-auto"
  end

  test "game page terminal green theme on mobile" do
    sign_in_as(@user)
    visit dev_game_path
    # Body has bg-stone-800 class
    assert_selector "body.bg-stone-800"
    # Terminal input area is visible
    assert_selector "#terminalInput", visible: true
  end

  test "sidebar toggle works on mobile" do
    sign_in_as(@user)
    visit dev_game_path
    # Sidebar should be hidden by default on mobile
    assert_selector "[data-mobile-nav-target='sidebar'].hidden", visible: false
    # Click sidebar toggle button
    find("[data-action*='toggleSidebar']").click
    # Sidebar should now be visible (hidden class removed)
    assert_no_selector "[data-mobile-nav-target='sidebar'].hidden"
    assert_selector "[data-mobile-nav-target='sidebar']", visible: true
  end

  test "can send game command on mobile" do
    sign_in_as(@user)
    visit dev_game_path
    assert_selector ".terminal-input", visible: true
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Town Square"
  end
end
