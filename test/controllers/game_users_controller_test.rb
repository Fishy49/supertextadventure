# frozen_string_literal: true

require "test_helper"

class GameUsersControllerTest < ActionDispatch::IntegrationTest
  test "should get online" do
    get game_users_online_url
    assert_response :success
  end

  test "should get offline" do
    get game_users_offline_url
    assert_response :success
  end

  test "should get typing" do
    get game_users_typing_url
    assert_response :success
  end

  test "should get not_typing" do
    get game_users_not_typing_url
    assert_response :success
  end
end
