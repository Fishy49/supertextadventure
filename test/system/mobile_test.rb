# frozen_string_literal: true

require_relative "../support/mobile_system_test_case"

class MobileTest < MobileSystemTestCase
  setup do
    @user = users(:player1)
    sign_in_as(@user)
  end

  test "home page is navigable on mobile" do
    visit root_path
    assert_text "SuperTextAdventure_v0.1"
    # Mobile nav bar should be visible (has md:hidden so visible at mobile size)
    assert_selector "[data-controller='mobile-nav']"
    # Click hamburger to open nav drawer
    find("[data-action*='toggleDrawer']").click
    assert_selector "[data-mobile-nav-target='drawer']"
    # Tavern link should be in drawer
    assert_text "Tavern"
  end

  test "hotkey footer hidden on mobile" do
    visit root_path
    # The footer has hidden md:grid — at mobile width it should be hidden
    assert_selector "footer.hidden", visible: false
    # Mobile nav is visible
    assert_selector "[data-controller='mobile-nav']", visible: true
  end

  test "mobile nav drawer toggles" do
    visit root_path
    # Drawer should initially be hidden (translate-y-full)
    assert_selector "[data-mobile-nav-target='drawer']", visible: false
    # Open it
    find("[data-action*='toggleDrawer']").click
    assert_selector "[data-mobile-nav-target='drawer']", visible: true
    # Should have nav links
    assert_text "Home"
    assert_text "Tavern"
    assert_text "About"
    assert_text "Logout"
    # Close it
    find("[data-action*='toggleDrawer']").click
    assert_selector "[data-mobile-nav-target='drawer']", visible: false
  end

  test "ascii art does not overflow on mobile" do
    visit root_path
    # ASCII wrapper should have overflow-x-auto to prevent layout breaking
    assert_selector "pre", visible: true
    # The wrapper div should have overflow-x-auto class
    assert_selector ".overflow-x-auto"
  end

  test "terminal green theme on mobile" do
    visit root_path
    # Body has bg-stone-800 class
    assert_selector "body.bg-stone-800"
    # Terminal input area is visible
    assert_selector "#terminalInput", visible: true
  end

  test "sidebar toggle works on mobile" do
    visit dev_game_path
    # Sidebar should be hidden by default on mobile
    assert_selector "[data-mobile-nav-target='sidebar']", visible: false
    # Click sidebar toggle button
    find("[data-action*='toggleSidebar']").click
    # Sidebar should now be visible
    assert_selector "[data-mobile-nav-target='sidebar']", visible: true
  end

  test "can send game command on mobile" do
    visit dev_game_path
    assert_selector ".terminal-input", visible: true
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Town Square"
  end
end
