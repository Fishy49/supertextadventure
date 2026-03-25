# frozen_string_literal: true

require "application_system_test_case"

class RegistrationTest < ApplicationSystemTestCase
  test "setup token activation flow" do
    token = SetupToken.create!

    visit user_activation_url(code: token.uuid)
    fill_in "Username", with: "newplayer"
    fill_in "Password", with: "hunter2hunter2"
    fill_in "user[password_confirmation]", with: "hunter2hunter2"
    click_on "Register"

    assert_text "NEWPLAYER IS NOW REGISTERED FOR ADVENTURE."
  end
end
