# frozen_string_literal: true

require "test_helper"

class SetupTokensControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get setup_tokens_index_url
    assert_response :success
  end

  test "should get create" do
    get setup_tokens_create_url
    assert_response :success
  end

  test "should get delete" do
    get setup_tokens_delete_url
    assert_response :success
  end
end
