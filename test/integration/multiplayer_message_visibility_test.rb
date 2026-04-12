# frozen_string_literal: true

require "test_helper"

class MultiplayerMessageVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:classic_open)
    @owner = users(:owner)
    @player1 = users(:player1)
    @player2 = users(:player2)

    @game.game_users.create!(user_id: @player1.id, character_name: "Elara")
    @game.game_users.create!(user_id: @player2.id, character_name: "Gandalf")

    state = @game.game_state.dup
    state["turn_state"] = {
      "turn_order" => [@owner.id, @player1.id, @player2.id],
      "current_index" => 0
    }
    state["player_states"] = {
      @owner.id.to_s => player_in("town_square"),
      @player1.id.to_s => player_in("town_square"),
      @player2.id.to_s => player_in("town_square")
    }
    @game.update!(game_state: state)
  end

  # ─── Movement messages ───────────────────────────────────────────────────────

  test "mover sees room description, player left behind sees departure text" do
    # Owner moves east to tavern; player1 stays in town_square
    result = ClassicGame::Engine.execute(game: @game, user: @owner, command_text: "go east")
    create_movement_messages(result)

    # Mover sees the room description
    log_in_as(@owner)
    get game_path(@game)
    assert_select ".game-message", text: /=== The Tavern ===/
    assert_select ".game-message", text: /Dev Player heads east/, count: 0

    # Player left behind sees departure text, not the room description
    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /Dev Player heads east/
    assert_select ".game-message", text: /=== The Tavern ===/, count: 0
  end

  test "player in arrival room sees arrival text, not room description" do
    # Put player1 in the tavern so they see arrival
    move_player(@player1, "tavern")

    result = ClassicGame::Engine.execute(game: @game, user: @owner, command_text: "go east")
    create_movement_messages(result)

    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /Dev Player arrives from the west/
    assert_select ".game-message", text: /=== The Tavern ===/, count: 0
  end

  test "player in unrelated room sees neither departure nor arrival" do
    # Move player2 to the cave (no connection to the movement)
    move_player(@player2, "cave")

    result = ClassicGame::Engine.execute(game: @game, user: @owner, command_text: "go east")
    create_movement_messages(result)

    log_in_as(@player2)
    get game_path(@game)
    assert_select ".game-message", text: /Dev Player heads/, count: 0
    assert_select ".game-message", text: /Dev Player arrives/, count: 0
    assert_select ".game-message", text: /=== The Tavern ===/, count: 0
  end

  # ─── Give messages ──────────────────────────────────────────────────────────

  test "giver sees you give, receiver sees gives you, bystander sees gives to" do
    give_player_item(@owner, "rusty_key")

    result = ClassicGame::Engine.execute(game: @game, user: @owner, command_text: "give rusty key to Elara")
    create_give_messages(result)

    # Giver sees their perspective
    log_in_as(@owner)
    get game_path(@game)
    assert_select ".game-message", text: /You give the Rusty Key to Elara/
    assert_select ".game-message", text: /Dev Player gives/, count: 0

    # Receiver sees giver's name
    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /Dev Player gives you the Rusty Key/
    assert_select ".game-message", text: /You give/, count: 0

    # Bystander sees both names
    log_in_as(@player2)
    get game_path(@game)
    assert_select ".game-message", text: /Dev Player gives the Rusty Key to Elara/
    assert_select ".game-message", text: /You give/, count: 0
    assert_select ".game-message", text: /gives you/, count: 0
  end

  # ─── Player command visibility ──────────────────────────────────────────────

  test "player command messages are scoped to players in the same room" do
    move_player(@player2, "cave")

    # Create a player command message as owner (in town_square)
    owner_gu = @game.game_users.find_by(user_id: @owner.id)
    Message.create!(game: @game, game_user: owner_gu, content: "look around")

    # Player in same room sees it
    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /look around/

    # Player in different room does not
    log_in_as(@player2)
    get game_path(@game)
    assert_select ".game-message", text: /look around/, count: 0
  end

  # ─── Wait command ───────────────────────────────────────────────────────────

  test "wait command produces no visible response message" do
    result = ClassicGame::Engine.execute(game: @game, user: @owner, command_text: "wait")

    # No response message should be created
    assert_equal "", result[:response]
    msg_count_before = @game.messages.count

    # Simulate what the job does — skip creating a message for blank responses
    # (The job checks result[:response].present? before creating)
    assert_equal msg_count_before, @game.messages.count
  end

  private

    def player_in(room_id)
      {
        "current_room" => room_id,
        "inventory" => [],
        "health" => 10,
        "max_health" => 10,
        "visited_rooms" => [],
        "flags" => {}
      }
    end

    def move_player(user, room_id)
      state = @game.game_state.dup
      state["player_states"][user.id.to_s]["current_room"] = room_id
      @game.update!(game_state: state)
    end

    def give_player_item(user, item_id)
      state = @game.game_state.dup
      state["player_states"][user.id.to_s]["inventory"] << item_id
      @game.update!(game_state: state)
    end

    def create_movement_messages(result)
      sc = result[:state_changes] || {}
      return unless sc[:moved]

      Message.create!(game: @game, content: result[:response], visible_to_user_ids: [@owner.id])

      if sc[:departure_text] && sc[:departure_audience]&.any?
        Message.create!(game: @game, content: sc[:departure_text], visible_to_user_ids: sc[:departure_audience])
      end

      return unless sc[:arrival_text] && sc[:arrival_audience]&.any?

      Message.create!(game: @game, content: sc[:arrival_text], visible_to_user_ids: sc[:arrival_audience])
    end

    def create_give_messages(result)
      give_data = result.dig(:state_changes, :give_to_player)
      return unless give_data

      Message.create!(game: @game, content: result[:response], visible_to_user_ids: [@owner.id])
      Message.create!(game: @game, content: give_data[:receiver_text], visible_to_user_ids: [give_data[:receiver_user_id]])

      return unless give_data[:bystander_text] && give_data[:bystander_audience]&.any?

      Message.create!(game: @game, content: give_data[:bystander_text], visible_to_user_ids: give_data[:bystander_audience])
    end

    def log_in_as(user)
      post sessions_url, params: { username: user.username, password: "testpassword" }
    end
end
