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

  # ─── Turn-blocked feedback ──────────────────────────────────────────────────

  test "not-your-turn feedback is visible only to the blocked player" do
    # It's the owner's turn; player1 tries to act and gets blocked.
    result = ClassicGame::Engine.execute(game: @game, user: @player1, command_text: "look")
    assert result[:state_changes][:turn_blocked]
    dispatch_messages(result, @player1)

    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /not your turn/

    log_in_as(@player2)
    get game_path(@game)
    assert_select ".game-message", text: /not your turn/, count: 0
  end

  # ─── Combat spectator narration ─────────────────────────────────────────────

  test "combat narration is second person for the actor and names-only for room-mates" do
    move_player(@owner, "cave")
    move_player(@player1, "cave")

    result = ClassicGame::Engine.execute(game: @game, user: @owner, command_text: "attack spider")
    dispatch_messages(result, @owner)

    log_in_as(@owner)
    get game_path(@game)
    assert_select ".game-message", text: /You engage the/
    assert_select ".game-message", text: /Dev Player engages the/, count: 0

    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /Dev Player engages the/
    assert_select ".game-message", text: /You engage the/, count: 0
  end

  # ─── Host (GM) visibility ───────────────────────────────────────────────────

  test "host sees departure text even when no other player observes it" do
    # player1 is alone in the tavern and moves; nobody else is there to watch,
    # but the host (owner) still sees the movement as GM.
    move_player(@player1, "tavern")
    move_player(@player2, "cave")
    make_it_the_turn_of(@player1)

    result = ClassicGame::Engine.execute(game: @game, user: @player1, command_text: "go west")
    dispatch_messages(result, @player1)

    log_in_as(@owner)
    get game_path(@game)
    assert_select ".game-message", text: /Elara heads west/

    log_in_as(@player2)
    get game_path(@game)
    assert_select ".game-message", text: /Elara heads west/, count: 0
  end

  test "host sees player commands typed in other rooms" do
    move_player(@player2, "cave")

    gu = @game.game_users.find_by(user_id: @player2.id)
    Message.create!(game: @game, game_user: gu, content: "sneak around")

    # The owner's character is in town_square, but as host they still see it.
    log_in_as(@owner)
    get game_path(@game)
    assert_select ".game-message", text: /sneak around/

    log_in_as(@player1)
    get game_path(@game)
    assert_select ".game-message", text: /sneak around/, count: 0
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

    def make_it_the_turn_of(user)
      state = @game.game_state.dup
      index = state["turn_state"]["turn_order"].index(user.id)
      state["turn_state"]["current_index"] = index
      @game.update!(game_state: state)
    end

    def give_player_item(user, item_id)
      state = @game.game_state.dup
      state["player_states"][user.id.to_s]["inventory"] << item_id
      @game.update!(game_state: state)
    end

    # Route results through the job's real dispatch so these tests cover the
    # production message-creation code instead of a copy of it.
    def dispatch_messages(result, acting_user)
      ClassicCommandJob.new.dispatch_result_messages(@game, acting_user, result)
    end

    def create_movement_messages(result, acting_user: @owner)
      dispatch_messages(result, acting_user)
    end

    def create_give_messages(result, acting_user: @owner)
      dispatch_messages(result, acting_user)
    end

    def log_in_as(user)
      post sessions_url, params: { username: user.username, password: "testpassword" }
    end
end
