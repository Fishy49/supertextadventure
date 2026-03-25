# frozen_string_literal: true

require "application_system_test_case"

class ErrorsTest < ApplicationSystemTestCase
  test "404 page" do
    visit "/this-path-does-not-exist-12345"
    assert_no_text "ActionController::RoutingError"
    assert_selector "body"
  end

  test "unauthenticated redirect" do
    visit games_url
    # Without login, CanCan should redirect away from games
    assert_no_current_path games_path
  end
end
