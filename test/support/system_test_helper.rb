# frozen_string_literal: true

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
      world.description = "A minimal world for QA / developer testing"
      world.world_data = {
        "meta" => {
          "starting_room" => "test_room",
          "version" => "1.0",
          "author" => "SuperTextAdventure"
        },
        "rooms" => {
          "test_room" => {
            "name" => "Test Chamber",
            "description" => "A bare stone chamber used for developer testing. Nothing of interest here.",
            "exits" => {},
            "items" => [],
            "npcs" => []
          }
        },
        "items" => {},
        "npcs" => {},
        "creatures" => {}
      }
    end
  end
end
