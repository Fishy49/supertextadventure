# frozen_string_literal: true

require "application_system_test_case"

class WorldBuilderTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:owner))
  end

  test "the builder loads the world onto the map" do
    visit edit_world_url(worlds(:qa_test_world))

    assert_selector "#map .node", minimum: 1
    assert_selector "#sidebarList .row", minimum: 1
    assert_selector "#btnSave"
  end

  test "worlds#show lands on the builder" do
    visit world_url(worlds(:qa_test_world))

    assert_selector "#map"
  end

  test "renaming the world and saving persists it" do
    world = worlds(:qa_test_world)
    visit edit_world_url(world)

    fill_in "worldName", with: "QA Test World Renamed"
    assert_selector "#saveState", exact_text: "Unsaved changes"
    click_button "Save"
    assert_selector "#saveState", exact_text: "Saved"

    assert_equal "QA Test World Renamed", world.reload.world_data.dig("meta", "name")
    assert_equal "QA Test World Renamed", world.name
  end
end
