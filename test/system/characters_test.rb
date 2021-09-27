# frozen_string_literal: true

require "application_system_test_case"

class CharactersTest < ApplicationSystemTestCase
  setup do
    @character = characters(:one)
  end

  test "visiting the index" do
    visit characters_url
    assert_selector "h1", text: "Characters"
  end

  test "creating a Character" do
    visit characters_url
    click_on "New Character"

    fill_in "Backstory", with: @character.backstory
    fill_in "Eye color", with: @character.eye_color
    fill_in "Hair color", with: @character.hair_color
    fill_in "Height", with: @character.height
    fill_in "Name", with: @character.name
    fill_in "Race", with: @character.race
    fill_in "User", with: @character.user_id
    click_on "Create Character"

    assert_text "Character was successfully created"
    click_on "Back"
  end

  test "updating a Character" do
    visit characters_url
    click_on "Edit", match: :first

    fill_in "Backstory", with: @character.backstory
    fill_in "Eye color", with: @character.eye_color
    fill_in "Hair color", with: @character.hair_color
    fill_in "Height", with: @character.height
    fill_in "Name", with: @character.name
    fill_in "Race", with: @character.race
    fill_in "User", with: @character.user_id
    click_on "Update Character"

    assert_text "Character was successfully updated"
    click_on "Back"
  end

  test "destroying a Character" do
    visit characters_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Character was successfully destroyed"
  end
end
