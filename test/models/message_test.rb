# frozen_string_literal: true

require "test_helper"

class MessageTest < ActiveSupport::TestCase
  # ─── visible_to scope ───────────────────────────────────────────────────────

  test "visible_to returns message when visible_to_user_ids is empty (global)" do
    game = games(:one)
    user = OpenStruct.new(id: 999)
    msg = Message.create!(game: game, content: "Global message", visible_to_user_ids: [])

    assert_includes Message.visible_to(user), msg
  end

  test "visible_to returns message when user_id is in visible_to_user_ids" do
    game = games(:one)
    user1 = OpenStruct.new(id: 1)
    msg = Message.create!(game: game, content: "Private message", visible_to_user_ids: [1])

    assert_includes Message.visible_to(user1), msg
  end

  test "visible_to excludes message when user_id not in visible_to_user_ids" do
    game = games(:one)
    user2 = OpenStruct.new(id: 2)
    msg = Message.create!(game: game, content: "Not for user 2", visible_to_user_ids: [1])

    assert_not_includes Message.visible_to(user2), msg
  end
end
