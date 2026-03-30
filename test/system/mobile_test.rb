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
    # Mobile nav bar should be visible
    assert_selector "[data-controller='mobile-nav']"
    # Click hamburger to open nav drawer
    find("[data-action*='toggleDrawer']").click
    # Drawer should be open (translate-y-0)
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-0"
    # Nav links should be in drawer (uppercase due to button class)
    within("[data-mobile-nav-target='drawer']") do
      assert_link "Tavern"
    end
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
    # Drawer should initially be off-screen (translate-y-full)
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-full"
    # Open it
    find("[data-action*='toggleDrawer']").click
    assert_selector "[data-mobile-nav-target='drawer'].translate-y-0"
    # Should have nav links (uppercase due to button CSS)
    within("[data-mobile-nav-target='drawer']") do
      assert_link "Home"
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
    assert_selector "[data-mobile-nav-target='sidebar'].hidden", visible: false
    # Click sidebar toggle button
    find("[data-action*='toggleSidebar']").click
    # Sidebar should now be visible (hidden class removed)
    assert_no_selector "[data-mobile-nav-target='sidebar'].hidden"
    assert_selector "[data-mobile-nav-target='sidebar']", visible: true
  end

  test "tavern command opens sidebar on mobile" do
    visit games_path
    assert_selector "#sidebar-panel.hidden", visible: false
    assert_selector "#mobile-sidebar-backdrop.hidden", visible: false
    # Type a command
    find(".terminal-input").click
    find(".terminal-input").send_keys("list tables", :return)
    # Sidebar should open with backdrop
    assert_no_selector "#sidebar-panel.hidden"
    assert_selector "#sidebar-panel", visible: true
    assert_no_selector "#mobile-sidebar-backdrop.hidden"
    assert_selector "#mobile-sidebar-backdrop", visible: true
  end

  test "tapping backdrop closes tavern sidebar on mobile" do
    visit games_path
    find(".terminal-input").click
    find(".terminal-input").send_keys("list tables", :return)
    assert_selector "#sidebar-panel", visible: true
    # Tap the backdrop (visible in the left 25% not covered by the 3/4-width sidebar)
    find_by_id("mobile-sidebar-backdrop").click(x: -150, y: 0)
    assert_selector "#sidebar-panel.hidden", visible: false
    assert_selector "#mobile-sidebar-backdrop.hidden", visible: false
  end

  test "can send game command on mobile" do
    visit dev_game_path
    assert_selector ".terminal-input", visible: true
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Town Square"
  end
end
