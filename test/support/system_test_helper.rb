# frozen_string_literal: true

require_relative "qa_world_data"

module SystemTestHelper
  def sign_in_as(user, password: "testpassword")
    visit login_url
    fill_in "username", with: user.username
    fill_in "password", with: password
    click_on "Login"
    assert_text "THOU HATH LOGGETHED IN!"
  end

  def create_qa_world
    World.find_or_create_by!(name: "QA Test World") do |world|
      world.description = "A full-featured world for QA / developer testing"
      world.world_data = TestSupport::QaWorldData.data
    end
  end
end
