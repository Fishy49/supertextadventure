> PR: https://github.com/Fishy49/supertextadventure/pull/33

# System Tests

## Acceptance Criteria

- Cuprite replaces Selenium as the system test driver; existing login test still passes
- `bin/rails test:system` runs all system tests headlessly in CI and passes on a clean checkout
- System tests cover: auth (login/logout), game lobby (browse/join), game hosting (create/start), classic game play via `/dev/game` (load, send command, reset), world editor (view/edit), and edge cases (404, unauthenticated redirect)
- A failing system test blocks CI (PR cannot be merged)
- No `sleep` calls in tests; all async assertions use Capybara's built-in retry

## Overview

Add a comprehensive system test suite that exercises the full browser stack using Capybara + Cuprite (Chrome DevTools Protocol, no Node/chromedriver process). These tests run in CI and catch regressions that unit/controller tests miss — things like Turbo Stream wiring, Stimulus controller behaviour, and multi-step user flows.

The existing `test/system/login_test.rb` uses Selenium + Chrome and is a good starting point, but we need broader coverage and a faster driver.

## Goals

- Replace the Selenium driver with Cuprite (CDP-based, faster, no chromedriver required)
- Add system tests for all critical user-facing flows
- Run headlessly in CI (`CI=true` or `HEADLESS=true` env var)
- Tests must be self-contained — no reliance on pre-existing DB rows beyond fixtures

## Driver: Cuprite

Add `cuprite` and `capybara-cuprite` gems to the `:test` group. Update `ApplicationSystemTestCase` to use Cuprite when `ENV["CI"]` is set or always. Cuprite connects directly to Chrome via CDP — no `webdrivers` or `chromedriver-helper` needed.

Keep the existing Selenium path as a fallback so developers can still run with `driven_by :selenium` locally if they prefer.

## Test Cases

### Authentication (`test/system/auth_test.rb`)

- **Login with valid credentials** — fill username/password, submit, see success flash
- **Login with invalid credentials** — see error message, stay on login page
- **Logout** — click logout, redirected to root, session cleared

### User Registration (`test/system/registration_test.rb`)

- **Setup token flow** — admin creates setup token, user visits activation URL, fills in username/password, account created and logged in

### Game Lobby (`test/system/lobby_test.rb`)

- **Browse open games** — logged-in user visits `/games/list`, sees at least one open game
- **Join a game** — click join on an open game, redirected to game lobby, player appears in player list

### Game Hosting (`test/system/host_test.rb`)

- **Create a game** — fill in name, select world, submit, redirected to game lobby
- **Start the game** — host submits first action from game page, message appears in terminal
- **Mute all players** — host clicks "Mute All", all player `can_message` toggled
- **Player list updates via Turbo** — second player joins (background request), host sidebar updates without page reload

### Classic Game Play (`test/system/classic_game_test.rb`)

This is the highest-value suite. Uses `/dev/game` (the debug shortcut) to skip auth/lobby setup.

- **Debug mode loads** — `GET /dev/game` redirects to game page, debug bar is visible at top
- **Initial room description** — after page load, terminal shows starting room description (Turbo Stream delivery confirmed)
- **Send a command** — type `look`, press Enter, response appears in terminal within timeout
- **Navigation command** — type a valid `go <direction>`, room description updates
- **Unknown command** — type gibberish, engine returns an "I don't understand" message
- **Reset game** — click "Reset Game" in debug bar, redirects back to `/dev/game`, fresh game created, terminal shows starting room again

### World Editor (`test/system/world_editor_test.rb`)

- **View world** — visit `/worlds/:id`, page renders world details
- **Edit room** — click edit on a room, update description, save, see updated text

### Error / Edge Cases

- **404 page** — visit a nonexistent path, see a friendly error page (not a Rails stack trace)
- **Unauthenticated redirect** — visit `/games/new` while logged out, redirected to login

## CI Integration

Add a Rake task or update the existing CI workflow (`.github/workflows/`) to run system tests after the unit test step:

```
bin/rails test:system
```

Set `HEADLESS=true` (or rely on `CI=true`) so Chrome runs headlessly. The job should fail if any system test fails, blocking the PR merge.

## Implementation Notes

- The `QA Test World` seed (used by `/dev/game`) must exist in the test database. Either run `db:seed` in CI or ensure the fixture/factory is created in test setup.
- Cuprite requires Chrome/Chromium to be installed on the CI runner. If using GitHub Actions, `actions/setup-chrome` or the default Ubuntu runner (which has Chrome) covers this.
- System tests are slow. Keep each test focused on a single flow. Use `Capybara.default_max_wait_time = 5` for Turbo Stream assertions.
- The `classic_game_test.rb` tests depend on `SuckerPunch` processing jobs inline. Either configure `SuckerPunch::Testing.inline!` in test setup or assert against the job being enqueued and fire it manually.
- Do not use `sleep` — use `assert_text` / `have_text` with Capybara's built-in retry.

---

## Implementation plan

> Generated 2026-03-25

### 1. Files to create

| Path | Purpose |
|------|---------|
| `test/system/auth_test.rb` | Login, invalid-login, and logout system tests |
| `test/system/registration_test.rb` | Setup-token activation and account-creation flow |
| `test/system/lobby_test.rb` | Browse open games list and join-game flow |
| `test/system/host_test.rb` | Create game, start game, mute-all players, Turbo player-list update |
| `test/system/classic_game_test.rb` | Full `/dev/game` flow: load, commands, reset |
| `test/system/world_editor_test.rb` | View world and edit-room description |
| `test/system/errors_test.rb` | 404 page and unauthenticated-redirect edge cases |
| `test/support/system_test_helper.rb` | Shared `sign_in_as` and `create_qa_world` helpers for system tests |

### 2. Files to modify

| Path | Specific changes |
|------|-----------------|
| `Gemfile` | Add `gem "cuprite"` and `gem "capybara-cuprite"` to the `:test` group; remove `gem "webdrivers"` |
| `test/application_system_test_case.rb` | Replace `driven_by :selenium` default with Cuprite when `ENV["CI"]` or `ENV["HEADLESS"]` is set; set `Capybara.default_max_wait_time = 5`; add `driven_by :cuprite` path |
| `.github/workflows/ci.yml` | Add a second job step (after "Run tests") that runs `bin/rails test:system` with `HEADLESS=true`; add Chrome setup step using `actions/setup-chrome@v1` |
| `test/fixtures/worlds.yml` | Add a `qa_test_world` fixture entry with minimal valid `world_data` JSON so `classic_game_test.rb` does not depend on `db:seed` |
| `test/fixtures/games.yml` | Add a `classic_open` fixture entry (game_type: classic, status: open, world: qa_test_world) for lobby and host tests |
| `test/fixtures/game_users.yml` | Add entries wiring `owner` into `classic_open` game so tests have a host already joined |
| `app/views/games/show.html.erb` | Change `Rails.env.development?` guards (lines 1 and 56) to also allow `test` env so the debug bar renders during system tests: `Rails.env.development? || Rails.env.test?` |

### 3. Implementation steps

**Step 1 — Add Cuprite gems**

In `Gemfile`, inside `group :test do`:
- Add `gem "cuprite"` (headless Chrome via CDP, no chromedriver)
- Add `gem "capybara-cuprite"` (Capybara driver registration)
- Remove `gem "webdrivers"` (no longer needed)

Run `bundle install` after editing.

**Step 2 — Update `ApplicationSystemTestCase`**

File: `test/application_system_test_case.rb`

Replace the entire file body with:

```ruby
# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["CI"] || ENV["HEADLESS"]
    driven_by :cuprite, using: :chrome, screen_size: [1400, 1400],
                        options: { headless: true }
  else
    driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  end

  Capybara.default_max_wait_time = 5
end
```

Why: Cuprite registers as `:cuprite` driver through `capybara-cuprite`. The fallback keeps developer local workflow intact.

**Step 3 — Add `system_test_helper.rb`**

File: `test/support/system_test_helper.rb`

Define module `SystemTestHelper` with two methods:

- `sign_in_as(user, password: "testpassword")` — visits `login_url`, fills username/password fields by label text, clicks "Login", asserts `assert_text "THOU HATH LOGGETHED IN!"`.
- `create_qa_world` — creates (or finds) a `World` with `name: "QA Test World"` and the minimal world_data hash from `db/seeds/feature_test_world.rb` (test_room with name "Test Chamber"). Returns the world. Used only in tests that cannot rely on the fixture.

Include this module in `ApplicationSystemTestCase` by adding `include SystemTestHelper` to that class.

**Step 4 — Add world and game fixtures**

File: `test/fixtures/worlds.yml` — add:

```yaml
qa_test_world:
  name: "QA Test World"
  description: "A minimal world for QA / developer testing"
  world_data: <%= {
    "meta" => { "starting_room" => "test_room", "version" => "1.0", "author" => "SuperTextAdventure" },
    "rooms" => { "test_room" => { "name" => "Test Chamber", "description" => "A bare stone chamber used for developer testing. Nothing of interest here.", "exits" => {}, "items" => [], "npcs" => [] } },
    "items" => {}, "npcs" => {}, "creatures" => {}
  }.to_json %>
```

Note: `world_data` is stored as JSONB; YAML ERB can produce the JSON string which Rails will parse on load.

File: `test/fixtures/games.yml` — add:

```yaml
classic_open:
  uuid: "classic-open-uuid-001"
  name: "Classic Open Game"
  game_type: "classic"
  created_by: 1
  status: "open"
  is_friends_only: false
  max_players: 4
  world: qa_test_world
  game_state: <%= {
    "world_snapshot" => { "meta" => { "starting_room" => "test_room" }, "rooms" => { "test_room" => { "name" => "Test Chamber", "description" => "A bare stone chamber.", "exits" => {}, "items" => [], "npcs" => [] } }, "items" => {}, "npcs" => {}, "creatures" => {} },
    "player_states" => {}, "room_states" => {}, "global_flags" => {}, "container_states" => {}
  }.to_json %>
```

File: `test/fixtures/game_users.yml` — add:

```yaml
owner_in_classic_open:
  game: classic_open
  user: owner
  character_name: "Dev Player"
```

**Step 5 — Fix debug-bar visibility for test env**

File: `app/views/games/show.html.erb`

Change line 1 from:
```erb
<% if Rails.env.development? && session[:dev_game_id].present? && session[:dev_game_id] == @game.id %>
```
to:
```erb
<% if (Rails.env.development? || Rails.env.test?) && session[:dev_game_id].present? && session[:dev_game_id] == @game.id %>
```

Change line 56 from:
```erb
<% if Rails.env.development? %>
```
to:
```erb
<% if Rails.env.development? || Rails.env.test? %>
```

Why: The debug bar and the game-state debugger panel are gated on `development?` only. System tests run in `test` env; without this change, `classic_game_test.rb` cannot assert the debug bar is visible.

**Step 6 — Update CI workflow**

File: `.github/workflows/ci.yml`

After the existing "Run tests" step, add:

```yaml
      - name: Set up Chrome
        uses: browser-actions/setup-chrome@v1

      - name: Run system tests
        run: bin/rails test:system
        env:
          HEADLESS: "true"
```

The "Set up Chrome" step must come before "Run system tests". The Ubuntu `ubuntu-latest` runner has Chrome pre-installed, but `browser-actions/setup-chrome@v1` pins a known version, which is more reliable. Either approach works; the explicit step is preferred for reproducibility.

**Step 7 — Write `test/system/auth_test.rb`**

Three tests using `users(:owner)` fixture:

1. `"login with valid credentials"` — calls `sign_in_as(users(:owner))`; asserts `assert_text "THOU HATH LOGGETHED IN!"`.
2. `"login with invalid credentials"` — visits `login_url`, fills incorrect password, clicks Login; asserts `assert_text` the invalid-login flash (check `config/locales/en.yml` or `t(:invalid_login)` for the exact string).
3. `"logout"` — `sign_in_as`, then visits `logout_url` (GET destroy), asserts `assert_text` the logged-out flash (`t(:logged_out)`).

**Step 8 — Write `test/system/registration_test.rb`**

One test: `"setup token activation flow"`.

Setup: `token = SetupToken.create!`
Steps: visit `user_activation_url(code: token.uuid)`, fill username + password + password_confirmation, click submit, assert redirect to root and `assert_text` success flash.

**Step 9 — Write `test/system/lobby_test.rb`**

Two tests, both with `sign_in_as(users(:owner))` in `setup`.

1. `"browse open games"` — visits `games_list_url`, `assert_text "Classic Open Game"` (from fixture).
2. `"join a game"` — visits `games_list_url`, clicks "Join" link for `classic_open` game (use `click_link` with text or `data-game-id` attribute), fills character name, submits; asserts redirect to game path and `assert_text users(:owner).username` in the players list.

Note: The game must have room for another player. Use `users(:player1)` as the `created_by` user so the owner can join, or adjust the `classic_open` fixture `created_by` to `player1 (id: 2)` instead of `owner (id: 1)`.

**Step 10 — Write `test/system/host_test.rb`**

Four tests, `setup` with `sign_in_as(users(:owner))`.

1. `"create a game"` — visits games path, clicks "New Game" (or navigates to `new_game_url`), fills name, selects world (classic type), submits; asserts redirect to game show page and `assert_text` game name.
2. `"start the game (first command)"` — uses the `classic_open` fixture game; visits `game_url(games(:classic_open).uuid)`; fills terminal input with "look"; submits; `assert_text "Test Chamber"` (the starting room name from the world snapshot).
3. `"mute all players"` — visits game show, clicks "Mute All" button; asserts (via Turbo) all player `can_message` are false (check for UI feedback text or absence of input).
4. `"player list updates via Turbo"` — signs in as owner, visits game; in a separate request (use `Capybara.using_session`) sign in as player2 and join the game; switch back to owner session; `assert_text users(:player2).username` without reloading the page.

**Step 11 — Write `test/system/classic_game_test.rb`**

Six tests. All rely on `GET /dev/game` which creates a dev user, finds/creates a game with `QA Test World`, and redirects. The `QA Test World` must exist in the test DB — the `qa_test_world` fixture (Step 4) provides this.

In `setup`, call `SuckerPunch::Testing.inline!` so `ClassicCommandJob` runs synchronously.

Tests:

1. `"debug mode loads"` — `visit dev_game_url`; `assert_current_path` matches `/games/`; `assert_selector "[data-controller='game-state-debugger']"` (or `assert_text "[ DEV ]"` from debug bar).
2. `"initial room description"` — `visit dev_game_url`; `assert_text "Test Chamber"` (first message already created on game setup).
3. `"send look command"` — visit `/dev/game`; find terminal input, fill "look", submit; `assert_text "Test Chamber"` (engine describe-room response).
4. `"unknown command"` — fill "xyzzy"; `assert_text "I don't understand"`.
5. `"navigation command"` — QA Test World has no exits, so update the fixture to add a north exit in Step 4, OR test that "go north" returns a "can't go that way" message. The simpler path: assert `assert_text "can't go"` or whatever the movement handler returns for no exit.
6. `"reset game"` — visit `/dev/game`; click "Reset Game" button (in debug bar, `method: :delete`, `data-turbo: false`); `assert_current_path dev_game_path`; `assert_text "Test Chamber"` (fresh game description).

**Step 12 — Write `test/system/world_editor_test.rb`**

Two tests, `sign_in_as(users(:owner))` in setup.

1. `"view world"` — `visit world_url(worlds(:qa_test_world))`; because `WorldsController#show` redirects to `edit_world_path`, assert `assert_selector "textarea#json-editor"` (the CodeMirror JSON editor).
2. `"edit room description"` — visit `edit_world_url(worlds(:qa_test_world))`; the world editor uses a JS CodeMirror editor, so direct `fill_in` won't work on the `<textarea>` (it's hidden). Instead: use `page.execute_script` to update the world_editor Stimulus controller's `jsonInput` textarea value, then click "Save". Assert `assert_text "World updated successfully"` flash.

Alternative approach (simpler, no JS injection): Use `update_entity` endpoint directly via a form. Load the `entity_form` for a room, update the description field, and save via the entity modal. Requires clicking "Edit" on a room entry in the preview panel. Assert `assert_text` the new description in the preview panel after save.

**Step 13 — Write `test/system/errors_test.rb`**

Two tests.

1. `"404 page"` — `visit "/this-path-does-not-exist-12345"`; assert the response does not contain "Application Error" (no Rails stack trace); `assert_selector "body"` (page renders). Note: In test env the error page may differ from production; adjust assertion to `assert_no_text "ActionController::RoutingError"`.
2. `"unauthenticated redirect"` — (no login) `visit new_game_url`; `assert_current_path` matches `check_for_setup` or root path (because `ApplicationController#check_for_setup` redirects unauthenticated users — actually it checks for owner user presence not auth, see notes below).

### 4. Test plan

**AC: Cuprite replaces Selenium as the system test driver; existing login test still passes**

- **Test name**: `AuthTest#test_login_with_valid_credentials`
- **Setup**: `ENV["CI"] = "true"` (set in CI workflow); `users(:owner)` fixture present
- **Input**: Visit `/login`, fill `username` = "Owner The User", `password` = "testpassword", click "Login"
- **Expected**: Page contains "THOU HATH LOGGETHED IN!"; driver in use is Cuprite (assert `Capybara.current_driver == :cuprite`)

---

**AC: `bin/rails test:system` runs all system tests headlessly in CI and passes on a clean checkout**

- **Test name**: CI workflow "Run system tests" step
- **Setup**: Fresh checkout; `db:schema:load`; `db:seed` OR fixtures include `qa_test_world`; `HEADLESS=true`; Chrome installed
- **Input**: `bin/rails test:system`
- **Expected**: Exit code 0; all test files in `test/system/` pass

---

**AC: Auth — Login with valid credentials**

- **Test name**: `AuthTest#test_login_with_valid_credentials`
- **Setup**: `users(:owner)` fixture (username: "Owner The User", password: "testpassword")
- **Input**: `login_url` → fill form → click "Login"
- **Expected**: `assert_text "THOU HATH LOGGETHED IN!"`

---

**AC: Auth — Login with invalid credentials**

- **Test name**: `AuthTest#test_login_with_invalid_credentials`
- **Setup**: `users(:owner)` fixture
- **Input**: Fill wrong password "wrongpassword", click "Login"
- **Expected**: `assert_text` the invalid-login I18n string (e.g. "Invalid login" — verify exact string in locale file)

---

**AC: Auth — Logout**

- **Test name**: `AuthTest#test_logout`
- **Setup**: `sign_in_as(users(:owner))`
- **Input**: `visit logout_url`
- **Expected**: `assert_text` logged-out flash; `assert_no_selector` any logged-in UI element

---

**AC: Registration — Setup token flow**

- **Test name**: `RegistrationTest#test_setup_token_activation_flow`
- **Setup**: `token = SetupToken.create!`
- **Input**: `visit user_activation_url(code: token.uuid)`, fill username "newplayer", password "hunter2", confirm password, submit
- **Expected**: `assert_text "newplayer is now registered for adventure."`

---

**AC: Lobby — Browse open games**

- **Test name**: `LobbyTest#test_browse_open_games`
- **Setup**: `sign_in_as(users(:owner))`; `games(:classic_open)` fixture present with status "open"
- **Input**: `visit games_list_url`
- **Expected**: `assert_text "Classic Open Game"`

---

**AC: Lobby — Join a game**

- **Test name**: `LobbyTest#test_join_a_game`
- **Setup**: `sign_in_as(users(:player1))`; `games(:classic_open)` created_by `users(:owner)` (so player1 can join)
- **Input**: Visit games list, click join on `classic_open`, fill character name "Adventurer", submit
- **Expected**: `assert_current_path` matches `/games/classic-open-uuid-001`; `assert_text "Player1 The User"` in player list

---

**AC: Hosting — Create a game**

- **Test name**: `HostTest#test_create_a_game`
- **Setup**: `sign_in_as(users(:owner))`; `worlds(:qa_test_world)` fixture present
- **Input**: Visit `new_game_url` (or click New Game from tavern), fill name "My New Game", select game_type "classic", select world "QA Test World", submit
- **Expected**: Redirected to game show; `assert_text "My New Game"`

---

**AC: Hosting — Start the game**

- **Test name**: `HostTest#test_start_the_game`
- **Setup**: `sign_in_as(users(:owner))`; visit `game_url(games(:classic_open).uuid)`; `SuckerPunch::Testing.inline!`
- **Input**: Fill terminal input with "look", press Enter
- **Expected**: `assert_text "Test Chamber"`

---

**AC: Hosting — Mute all players**

- **Test name**: `HostTest#test_mute_all_players`
- **Setup**: `sign_in_as(users(:owner))`; `games(:classic_open)` with `game_users(:owner_in_classic_open)` and player1 also joined
- **Input**: Click "Mute All" button on game show page
- **Expected**: `assert_text "Mute All"` button still present; all players' `can_message` attribute becomes false (verify via `assert_no_selector "input[data-message-enabled]"` or whatever the player list renders)

---

**AC: Classic game — Debug mode loads**

- **Test name**: `ClassicGameTest#test_debug_mode_loads`
- **Setup**: `worlds(:qa_test_world)` fixture; `SuckerPunch::Testing.inline!`
- **Input**: `visit dev_game_url`
- **Expected**: `assert_current_path %r{/games/}` (redirected to game show); `assert_text "[ DEV ]"` (debug bar rendered)

---

**AC: Classic game — Initial room description**

- **Test name**: `ClassicGameTest#test_initial_room_description`
- **Setup**: same
- **Input**: `visit dev_game_url`
- **Expected**: `assert_text "Test Chamber"`

---

**AC: Classic game — Send a command**

- **Test name**: `ClassicGameTest#test_send_look_command`
- **Setup**: visit `/dev/game`; `SuckerPunch::Testing.inline!`
- **Input**: Fill terminal input with "look", press Enter (submit form or Turbo)
- **Expected**: `assert_text "Test Chamber"` (room re-described)

---

**AC: Classic game — Unknown command**

- **Test name**: `ClassicGameTest#test_unknown_command`
- **Setup**: visit `/dev/game`
- **Input**: Fill terminal with "xyzzy", press Enter
- **Expected**: `assert_text "I don't understand"`

---

**AC: Classic game — Reset game**

- **Test name**: `ClassicGameTest#test_reset_game`
- **Setup**: visit `/dev/game`
- **Input**: Click "Reset Game" button in debug bar
- **Expected**: `assert_current_path dev_game_path` (or redirected back); `assert_text "Test Chamber"` (fresh game)

---

**AC: World editor — View world**

- **Test name**: `WorldEditorTest#test_view_world`
- **Setup**: `sign_in_as(users(:owner))`; `worlds(:qa_test_world)` fixture
- **Input**: `visit world_url(worlds(:qa_test_world))`
- **Expected**: `assert_selector "textarea#json-editor"` (redirected to edit, editor present)

---

**AC: World editor — Edit room**

- **Test name**: `WorldEditorTest#test_edit_room_description`
- **Setup**: `sign_in_as(users(:owner))`; `worlds(:qa_test_world)` fixture
- **Input**: Visit edit world page; click "Edit" on "test_room" room entry in preview panel; fill description "Updated description"; click Save in modal
- **Expected**: `assert_text "Updated description"` in preview panel; or `assert_text "World updated successfully"` flash

---

**AC: 404 page**

- **Test name**: `ErrorsTest#test_404_page`
- **Setup**: none
- **Input**: `visit "/nonexistent-path-xyz"`
- **Expected**: `assert_no_text "ActionController::RoutingError"`; `assert_selector "body"` (page renders cleanly)

---

**AC: Unauthenticated redirect**

- **Test name**: `ErrorsTest#test_unauthenticated_redirect`
- **Setup**: no session
- **Input**: `visit games_url` (requires login via CanCan or session check)
- **Expected**: `assert_current_path` root_path or login_path (redirected away from games)

---

**AC: No `sleep` calls in tests**

- Enforced by code review and RuboCop. `rubocop-capybara` includes `Capybara/NegationMatcher` and style cops that flag `sleep`. All async assertions must use `assert_text` / `have_text`.

### 5. Gotchas and constraints

**Debug bar visibility in test env**

The debug bar (`_debug_bar.html.erb`) is only rendered when `Rails.env.development?` is true (line 1 of `show.html.erb`). System tests run in `RAILS_ENV=test`. The guard must be expanded to `Rails.env.development? || Rails.env.test?` or the classic-game system tests will not see the debug bar or the "Reset Game" button. This is a required code change (Step 5).

**`/dev/game` route is excluded in production only**

The route is defined with `unless Rails.env.production?` so it is available in test env. The `Dev::GameController#require_development!` guard checks `rails_env.production?` — this is fine for test env (not production). No change needed here.

**SuckerPunch is asynchronous by default**

`ClassicCommandJob` is a SuckerPunch job. In the test env, SuckerPunch runs jobs in a thread pool, not inline. For system tests that assert game-engine responses appear in the terminal, call `SuckerPunch::Testing.inline!` in the test's `setup` block or in a `ApplicationSystemTestCase` setup hook. Without this, `assert_text "Test Chamber"` after sending a command will time out.

**`QA Test World` seed vs. fixture**

The `db:seeds.rb` creates the QA Test World, but CI currently only runs `db:schema:load`, not `db:seed`. The plan adds `qa_test_world` as a fixture (Step 4). This is the correct approach for test isolation and avoids adding `db:seed` to CI. The `world_data` JSON in the fixture must match what `Dev::GameController` expects (a world named exactly `"QA Test World"`).

**Fixture `world_data` JSONB format**

Rails fixtures for JSONB columns accept a raw JSON string (wrapped in ERB `<%= ... %>`). Use `.to_json` to serialize the hash. Alternatively, use a YAML multiline string with raw JSON. Confirm the column name in the schema matches `world_data` (it does, per `Game` model).

**Lobby test: `created_by` ownership**

`Game.joinable_by_user(user)` scopes to `where.not(created_by: user.id)`. If `classic_open` is `created_by: 1` (owner), then `users(:owner)` cannot join their own game. The join test must use `sign_in_as(users(:player1))`. Update the join test's setup accordingly, or change the fixture `created_by` to `player2 (id: 3)` to allow both owner and player1 to join.

**Turbo-stream in test env**

Turbo Streams are delivered over Action Cable WebSocket. In system tests, Capybara drives a real browser (Chrome via Cuprite) against the test Rails server, so Action Cable works. However, ensure the test `cable.yml` uses `async` adapter (not Redis), which is the Rails default in test env. Confirm `config/cable.yml` has `test: adapter: test` or `adapter: async`.

**RuboCop — double-quoted strings**

All new `.rb` files must use double-quoted strings (`Style/StringLiterals: EnforcedStyle: double_quotes`).

**RuboCop — MethodLength max 60**

Each test method must be under 60 lines. The large `setup` blocks or multi-step flows should be extracted to helper methods in `system_test_helper.rb`.

**RuboCop — `rubocop-capybara` plugin**

The `.rubocop.yml` already loads `rubocop-capybara`. This will enforce Capybara best practices: no `sleep`, use `have_selector` over `find` for assertions, use `fill_in` label over CSS selectors, etc.

**`check_for_setup` before-action**

`ApplicationController` runs `check_for_setup` on every request, redirecting to `/setup` if no owner user exists. Fixtures include `users(:owner)` with `is_owner: true`, so this is satisfied for all tests. The `errors_test.rb` unauthenticated redirect test will also pass through this check first — since the owner fixture exists, it will not redirect to setup.

**World editor JS editor**

The world editor uses CodeMirror (a JavaScript rich-text editor). The actual `<textarea id="json-editor">` is hidden (`class="hidden"`). Direct `fill_in "json-editor"` will not work. Use `page.execute_script` to set the CodeMirror value, or test via the entity modal (click Edit on a room in the preview panel) which uses standard HTML form fields. The entity-modal path is more reliable for system tests.

**`create_from_activation` path for registration**

The registration form submits to `users_activation_path` (POST `users/create-from-activation`). The activation page is at `user_activation_url(code: token.uuid)`. The `activate` action renders `users/new` template with the token. The form in that template must include the `code` param. Verify `app/views/users/new.html.erb` includes a hidden `code` field bound to `@token.uuid`; if it does not, this is a pre-existing bug and the registration test will fail at form submission.
