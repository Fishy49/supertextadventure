# frozen_string_literal: true

require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects with valid session" do
      user = users(:owner)

      connect params: {}, session: { "user_id" => user.id }

      assert_equal user, connection.current_user
    end

    test "rejects connection without session" do
      assert_reject_connection { connect }
    end

    test "rejects connection with invalid user_id" do
      assert_reject_connection do
        connect params: {}, session: { "user_id" => 999_999 }
      end
    end
  end
end
