# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  # ─── Unauthenticated access redirects to login ──────────────────────────────

  test "unauthenticated GET /tavern redirects to login" do
    get tavern_url
    assert_redirected_to root_path
    assert_equal I18n.t(:login_required), flash[:notice]
  end

  test "unauthenticated GET /games redirects to login" do
    get games_url
    assert_redirected_to root_path
  end

  test "unauthenticated GET /games/list redirects to login" do
    get games_list_url
    assert_redirected_to root_path
  end

  test "unauthenticated GET /users redirects to login" do
    get users_url
    assert_redirected_to root_path
  end

  test "unauthenticated GET /users/:id redirects to login" do
    get user_url(users(:player1))
    assert_redirected_to root_path
  end

  test "unauthenticated GET /setup_tokens redirects to login" do
    get setup_tokens_url
    assert_redirected_to root_path
  end

  test "unauthenticated GET /worlds redirects to login" do
    get worlds_url
    assert_redirected_to root_path
  end

  test "unauthenticated GET /worlds/:id/edit redirects to login" do
    get edit_world_url(worlds(:qa_test_world))
    assert_redirected_to root_path
  end

  test "unauthenticated POST /messages redirects to login" do
    post create_message_url, params: { message: { game_id: games(:classic_open).id, content: "hack" } }
    assert_redirected_to root_path
  end

  test "unauthenticated PATCH /game_users/:id redirects to login" do
    patch game_user_url(game_users(:owner_in_classic_open)),
          params: { game_user: { heal: 10, damage: 0, can_message: "true" } }
    assert_redirected_to root_path
  end

  # ─── Public routes remain accessible ────────────────────────────────────────

  test "login page is accessible without auth" do
    get root_url
    assert_response :ok
  end

  test "setup page is accessible when no owner exists" do
    User.where(is_owner: true).update_all(is_owner: false) # rubocop:disable Rails/SkipsModelValidations
    get setup_url
    assert_response :ok
  end

  test "activation link is accessible without auth" do
    token = SetupToken.create!
    get user_activation_url(code: token.uuid)
    assert_response :ok
  end

  # ─── Setup re-entry blocked ────────────────────────────────────────────────

  test "setup page redirects when owner already exists" do
    assert User.exists?(is_owner: true)
    log_in_as users(:owner)

    get setup_url
    assert_redirected_to root_path
  end

  # ─── Authorization: users can only edit themselves ─────────────────────────

  test "non-owner cannot edit another user" do
    log_in_as users(:player1)

    get edit_user_url(users(:player2))
    assert_redirected_to root_path
  end

  test "user can edit their own profile" do
    log_in_as users(:player1)

    get edit_user_url(users(:player1))
    assert_response :ok
  end

  test "owner can edit any user" do
    log_in_as users(:owner)

    get edit_user_url(users(:player1))
    assert_response :ok
  end

  # ─── Authorization: only owner can list/destroy users ──────────────────────

  test "non-owner cannot access user index" do
    log_in_as users(:player1)

    get users_url
    assert_redirected_to root_path
  end

  test "owner can access user index" do
    log_in_as users(:owner)

    get users_url
    assert_response :ok
  end

  # ─── Host-only controller access ──────────────────────────────────────────

  test "non-host cannot update current context" do
    log_in_as users(:player1)
    game = games(:classic_open)

    patch game_update_context_url(game_id: game.id),
          params: { game: { current_context: "hacked" } }
    assert_response :forbidden
  end

  test "non-host cannot mute players" do
    log_in_as users(:player1)
    game = games(:classic_open)

    patch game_users_mute_or_unmute_url(game_id: game.id),
          params: { game_user: { can_message: "false" } }
    assert_response :forbidden
  end

  # ─── Message access requires game participation ────────────────────────────

  test "non-participant cannot post messages to a game" do
    log_in_as users(:player2)
    game = games(:classic_open)

    post create_message_url,
         params: { message: { game_id: game.id, content: "intruder" } }
    assert_response :forbidden
  end

  # ─── CSP headers include Google Fonts allowlist ────────────────────────────

  test "CSP header allows Google Fonts" do
    log_in_as users(:owner)

    get tavern_url
    csp = response.headers["Content-Security-Policy"]

    assert_includes csp, "fonts.googleapis.com"
    assert_includes csp, "fonts.gstatic.com"
    assert_includes csp, "'self'"
    assert_includes csp, "object-src 'none'"
  end

  # ─── Session fixation prevention ───────────────────────────────────────────

  test "session ID changes on login" do
    get root_url
    cookie_before = cookies[Rails.application.config.session_options[:key]]

    post sessions_url, params: { username: users(:owner).username, password: "testpassword" }
    cookie_after = cookies[Rails.application.config.session_options[:key]]

    assert_not_equal cookie_before, cookie_after, "Session cookie should change after login"
  end

  # ─── Token expiration ─────────────────────────────────────────────────────

  test "expired tokens are not considered active" do
    token = SetupToken.create!
    token.update_column(:expires_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

    assert_not token.reload.active?
    assert_empty SetupToken.active.where(id: token.id)
  end

  test "valid tokens are active" do
    token = SetupToken.create!

    assert token.active?
    assert_includes SetupToken.active, token
  end

  private

    def log_in_as(user)
      post sessions_url, params: { username: user.username, password: "testpassword" }
    end
end
