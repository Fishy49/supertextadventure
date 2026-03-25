# frozen_string_literal: true

require "application_system_test_case"

class WorldEditorTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:owner))
  end

  test "view world" do
    visit world_url(worlds(:qa_test_world))
    # worlds#show redirects to edit_world_path which renders the editor
    assert_selector "textarea#json-editor", visible: :all
  end

  test "edit room description via entity modal" do
    visit edit_world_url(worlds(:qa_test_world))
    # Click the Edit button for the test_room in the preview panel
    first(:link, "Edit", href: /entity_form.*entity_id=test_room/).click
    # Wait for the entity modal slide panel to appear
    assert_selector "textarea[name='description']"
    fill_in "description", with: "Updated room description for testing"
    find("input[type='submit'][value='Save']").click
    assert_text "Updated room description for testing"
  end
end
