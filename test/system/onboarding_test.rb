# frozen_string_literal: true

require "application_system_test_case"

class OnboardingTest < ApplicationSystemTestCase
  setup do
    json = JSON.parse(Rails.root.join("games/the_tipsy_dragon.json").read)
    World.find_or_create_by!(name: json.dig("meta", "name")) do |world|
      world.description = json.dig("meta", "description") || ""
      world.world_data = json
    end
  end

  test "new player sees onboarding game after login" do
    player = users(:player1)
    sign_in_as(player)

    assert_text "Ye Olde Tavern"
    assert_text "#{player.username}'s First Adventure"
    assert_selector "span", text: "PLAYING"
  end

  test "onboarding game is playable" do
    sign_in_as(users(:player1))

    click_on "Player1 The User's First Adventure"
    assert_selector ".terminal-input"
    find(".terminal-input").click
    find(".terminal-input").send_keys("look", :return)
    assert_text "Cellar"
  end

  test "onboarding game is not created if player already has games" do
    player = users(:owner)
    sign_in_as(player)

    assert_text "Ye Olde Tavern"
    assert_no_text "First Adventure"
  end

  test "registration then login creates onboarding game" do
    token = SetupToken.create!

    visit user_activation_url(code: token.uuid)
    fill_in "Username", with: "newadventurer"
    fill_in "Password", with: "hunter2hunter2"
    fill_in "user[password_confirmation]", with: "hunter2hunter2"
    click_on "Register"

    assert_text "NEWADVENTURER IS NOW REGISTERED FOR ADVENTURE."

    fill_in "username", with: "newadventurer"
    fill_in "password", with: "hunter2hunter2"
    click_on "Login"
    assert_text "THOU HATH LOGGETHED IN!"

    assert_text "Ye Olde Tavern"
    assert_text "newadventurer's First Adventure"
  end

  test "game creation from tavern lands in game view" do
    sign_in_as(users(:owner))
    visit tavern_url
    click_on "Start a New Game"

    fill_in "game[name]", with: "My Test Adventure"
    select "Classic Mode", from: "game[game_type]"
    select "The Tipsy Dragon", from: "game[world_id]"
    click_on "Create Game"

    assert_text "My Test Adventure"
    assert_selector ".terminal-input"
  end

  test "game page uses application layout with sidebar and terminal" do
    sign_in_as(users(:owner))
    visit game_url(id: games(:classic_open).uuid)

    assert_selector ".terminal-input"
    assert_selector "#sidebar-panel"
  end
end
