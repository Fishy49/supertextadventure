# frozen_string_literal: true

require "application_system_test_case"

class HostTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:owner))
  end

  test "create a game via tavern terminal" do
    visit tavern_url
    # Trigger the new game form via the tavern's terminal controller
    find(".terminal-input").click
    find(".terminal-input").send_keys("new table", :return)
    # Wait for the game form to load in the sidebar via turbo-stream
    assert_selector "input[name='game[name]']"
    fill_in "game[name]", with: "My New Game"
    select "Classic Mode", from: "game[game_type]"
    # World selector appears after selecting Classic Mode
    select "QA Test World", from: "game[world_id]"
    click_on "Create Game"
    assert_text "My New Game"
  end

  test "start the game via terminal command" do
    visit game_url(id: games(:classic_open).uuid)
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Town Square"
  end

  test "mute all players" do
    visit game_url(id: games(:classic_open).uuid)
    click_on "Mute All"
    assert_selector "input[value='Mute All']"
  end
end
