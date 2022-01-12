# frozen_string_literal: true

require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  setup do
    @game = games(:one)
  end

  test "visiting the index" do
    visit games_url
    assert_selector "h1", text: "Games"
  end

  test "should create game" do
    visit games_url
    click_on "New game"

    fill_in "Closed at", with: @game.closed_at
    fill_in "Created by", with: @game.created_by
    fill_in "Game type", with: @game.game_type
    check "Is friends only" if @game.is_friends_only
    fill_in "Max players", with: @game.max_players
    fill_in "Name", with: @game.name
    fill_in "Opened at", with: @game.opened_at
    fill_in "Status", with: @game.status
    fill_in "Uuid", with: @game.uuid
    click_on "Create Game"

    assert_text "Game was successfully created"
    click_on "Back"
  end

  test "should update Game" do
    visit game_url(@game)
    click_on "Edit this game", match: :first

    fill_in "Closed at", with: @game.closed_at
    fill_in "Created by", with: @game.created_by
    fill_in "Game type", with: @game.game_type
    check "Is friends only" if @game.is_friends_only
    fill_in "Max players", with: @game.max_players
    fill_in "Name", with: @game.name
    fill_in "Opened at", with: @game.opened_at
    fill_in "Status", with: @game.status
    fill_in "Uuid", with: @game.uuid
    click_on "Update Game"

    assert_text "Game was successfully updated"
    click_on "Back"
  end

  test "should destroy Game" do
    visit game_url(@game)
    click_on "Destroy this game", match: :first

    assert_text "Game was successfully destroyed"
  end
end
