# frozen_string_literal: true

require "application_system_test_case"

class LoginTest < ApplicationSystemTestCase
  setup do
    @user = users(:owner)
  end

  test "should log in" do
    visit root_url
    fill_in "username", with: @user.username
    fill_in "password", with: "testpassword"

    click_on "Login"

    assert_text "THOU HATH LOGGETHED IN!"
  end
end
