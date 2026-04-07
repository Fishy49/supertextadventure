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

  test "login page has scan line overlay" do
    visit root_url
    assert_selector ".crt-scanlines"
  end

  test "login page shows background narrative" do
    visit root_url
    sleep 4
    assert_selector ".login-narrative-line", minimum: 1
  end

  test "narrative does not block form interaction" do
    visit root_url
    fill_in "username", with: "test"
    assert_field "username", with: "test"
  end

  test "login page elements stack correctly" do
    visit root_url
    assert_selector ".crt-scanlines"
    assert_selector "[data-controller='login-narrative']"
    assert_selector "input[name='username']"
  end
end
