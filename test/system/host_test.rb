# frozen_string_literal: true

require "application_system_test_case"

class HostTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:owner))
  end

  test "create a game via tavern" do
    visit tavern_url
    click_on "Start a New Game"
    assert_selector "input[name='game[name]']"
    fill_in "game[name]", with: "My New Game"
    select "Classic Mode", from: "game[game_type]"
    select "QA Test World", from: "game[world_id]"
    click_on "Create Game"
    assert_text "My New Game"
  end

  test "edit a game via tavern preserves unchanged fields" do
    game = games(:classic_open)

    visit tavern_url
    within "##{ActionView::RecordIdentifier.dom_id(game)}" do
      click_on "Edit"
    end

    assert_selector "h1", text: "Editing game"
    fill_in "game[name]", with: "Classic Open Renamed"
    click_on "Update Game"

    assert_text "Classic Open Renamed"
    assert_no_selector "h1", text: "Editing game"

    game.reload
    assert_equal "Classic Open Renamed", game.name
    assert_equal "classic", game.game_type, "editing the name must not reset game_type"
    assert_equal "open", game.status, "editing the name must not reset status"
  end

  test "delete a game via tavern removes the card from the UI" do
    game = games(:classic_open)

    visit tavern_url
    assert_text game.name

    accept_confirm do
      within "##{ActionView::RecordIdentifier.dom_id(game)}" do
        click_on "Delete"
      end
    end

    assert_no_text game.name
    assert_nil Game.find_by(id: game.id)
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
