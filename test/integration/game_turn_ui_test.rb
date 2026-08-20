# frozen_string_literal: true

require "test_helper"

class GameTurnUiTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:classic_open)
    @owner = users(:owner)
    @player1 = users(:player1)

    @game.game_users.create!(user_id: @player1.id, character_name: "Ranger")

    state = @game.game_state.dup
    state["turn_state"] = { "turn_order" => [@owner.id, @player1.id], "current_index" => 0 }
    @game.update!(game_state: state)
  end

  test "current-turn player sees the terminal input unhidden" do
    log_in_as(@owner)
    get game_path(@game)

    assert_select "#text_form_content #terminalInput"
    assert_select "#text_form_content > div.hidden", count: 0
    assert_no_match(/Waiting for/, response.body)
  end

  test "off-turn player sees a waiting message and the input is hidden" do
    log_in_as(@player1)
    get game_path(@game)

    assert_match(/Waiting for Dev Player/, response.body)
    assert_select "#text_form_content > div.hidden #terminalInput"
  end

  test "player in combat limbo sees the waiting-for-combat message" do
    state = @game.game_state.dup
    state["player_states"] ||= {}
    state["player_states"][@owner.id.to_s] = {
      "current_room" => "town_square",
      "health" => 10,
      "max_health" => 10,
      "inventory" => [],
      "waiting_for_combat_end" => true
    }
    @game.update!(game_state: state)

    log_in_as(@owner)
    get game_path(@game)

    assert_match(/Waiting for combat to finish/, response.body)
    assert_select "#text_form_content > div.hidden #terminalInput"
  end

  private

    def log_in_as(user)
      post sessions_url, params: { username: user.username, password: "testpassword" }
    end
end
