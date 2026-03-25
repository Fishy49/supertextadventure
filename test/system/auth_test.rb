# frozen_string_literal: true

require "application_system_test_case"

class AuthTest < ApplicationSystemTestCase
  test "login with valid credentials" do
    sign_in_as(users(:owner))
  end

  test "login with invalid credentials" do
    visit login_url
    fill_in "username", with: users(:owner).username
    fill_in "password", with: "wrongpassword"
    click_on "Login"
    assert_text "THY NAME IS UNKNOWN OR THY PASSWORD IS RANK!"
  end

  test "logout" do
    sign_in_as(users(:owner))
    visit logout_url
    assert_text "AWAY WITH YE!"
  end
end
