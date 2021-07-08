# frozen_string_literal: true

require "application_system_test_case"

class FriendRequestsTest < ApplicationSystemTestCase
  setup do
    @friend_request = friend_requests(:one)
  end

  test "visiting the index" do
    visit friend_requests_url
    assert_selector "h1", text: "Friend Requests"
  end

  test "creating a Friend request" do
    visit friend_requests_url
    click_on "New Friend Request"

    fill_in "Accepted on", with: @friend_request.accepted_on
    fill_in "Rejected on", with: @friend_request.rejected_on
    fill_in "Requestee", with: @friend_request.requestee_id
    fill_in "Requester", with: @friend_request.requester_id
    fill_in "Status", with: @friend_request.status
    click_on "Create Friend request"

    assert_text "Friend request was successfully created"
    click_on "Back"
  end

  test "updating a Friend request" do
    visit friend_requests_url
    click_on "Edit", match: :first

    fill_in "Accepted on", with: @friend_request.accepted_on
    fill_in "Rejected on", with: @friend_request.rejected_on
    fill_in "Requestee", with: @friend_request.requestee_id
    fill_in "Requester", with: @friend_request.requester_id
    fill_in "Status", with: @friend_request.status
    click_on "Update Friend request"

    assert_text "Friend request was successfully updated"
    click_on "Back"
  end

  test "destroying a Friend request" do
    visit friend_requests_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Friend request was successfully destroyed"
  end
end
