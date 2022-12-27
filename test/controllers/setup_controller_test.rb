# frozen_string_literal: true

require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get setup_index_url
    assert_response :success
  end

  test "should get setup" do
    get setup_setup_url
    assert_response :success
  end

  test "should get list_tokens" do
    get setup_list_tokens_url
    assert_response :success
  end

  test "should get create_token" do
    get setup_create_token_url
    assert_response :success
  end

  test "should get delete_token" do
    get setup_delete_token_url
    assert_response :success
  end
end
