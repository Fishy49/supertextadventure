# frozen_string_literal: true

require "application_system_test_case"

class LobbyTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:owner))
  end

  test "browse open games" do
    visit games_list_url
    assert_text "Classic Open Game"
  end

  test "join a game as another player" do
    sign_in_as(users(:player1))
    visit game_lobby_url(id: games(:classic_open).uuid)
    fill_in "Character name", with: "Adventurer"
    click_on "Join Table"
    assert_current_path game_path(id: games(:classic_open).uuid)
    assert_text "Classic Open Game"
  end
end
