> PR: https://github.com/Fishy49/supertextadventure/pull/32

# Debug Game Mode

A special route available only in development that drops a developer directly
into a running game with no authentication, no setup, and a one-click reset.
Eliminates the spin-up friction of manual QA testing.

---

## Player-facing behaviour

### Accessing the route
```
GET /dev/game
```
Visiting this URL in development:
- Creates a dev session with a spoofed user (fixed dev user id, username "Dev Player")
- Finds or creates a game using the QA test world
- Redirects immediately to the game's play view

No login, no game creation form, no world selection.

### The game interface
The normal game UI is shown with one addition: a **debug bar** fixed to the
top of the screen containing:
- The current room id
- The player's inventory (comma-separated item ids)
- Any active flags (key: value pairs)
- A **Reset Game** button

### Resetting
Clicking Reset Game:
- Destroys the current dev game
- Creates a fresh one from the QA test world
- Redirects back to `/dev/game`

The player is back in the starting room with empty inventory in under a second.

---

## Constraints

- The `/dev/game` route and the debug bar must be **completely absent in
  production**. Raise `ActionController::RoutingError` (or equivalent) if
  accessed outside development.
- No real authentication is performed. The spoofed user id is a fixed constant
  (e.g. `0` or a clearly fake value like `999999`) that cannot collide with
  real user ids.
- The dev game is identified by the spoofed user id — there is exactly one dev
  game at any time. If one already exists, reuse it; don't create duplicates.
- The QA test world must exist (seeded via `db/seeds/feature_test_world.rb`).
  If it doesn't exist, show a clear error message with the seed command to run.

---

## Acceptance criteria

- `GET /dev/game` in development creates a dev session and redirects to the game
- If a dev game already exists for the spoofed user, it is reused (not duplicated)
- If no dev game exists, one is created using the QA test world
- The debug bar is visible on the game page showing room id, inventory, and flags
- Clicking Reset destroys the current game, creates a fresh one, and redirects to `/dev/game`
- `GET /dev/game` in production raises a routing error (returns 404)
- If the QA test world seed has not been run, a clear error page is shown with
  the command needed to fix it

## Out of scope
- Authentication of any kind on this route
- The debug bar appearing on any page other than the dev game
- Persisting dev game state across server restarts (acceptable if it resets)
- The QA test world itself (covered by a separate spec)

---

## Implementation plan

> Generated 2026-03-23

### 1. Files to create

- `app/controllers/dev/game_controller.rb` — handles `GET /dev/game` (find-or-create dev game, set spoofed session, redirect) and `DELETE /dev/game` (reset: destroy + redirect back); enforces development-only access via before_action
- `app/views/games/_debug_bar.html.erb` — partial rendered conditionally in games/show for dev sessions; shows room id, inventory, and flags with a Reset Game button using `button_to`
- `app/views/dev/game/missing_world.html.erb` — error page shown when QA Test World has not been seeded; displays the seed command
- `db/seeds/feature_test_world.rb` — seeds the QA test world ("QA Test World") used by the dev game
- `test/controllers/dev/game_controller_test.rb` — integration tests covering all acceptance criteria

### 2. Files to modify

- `config/routes.rb` — add `if Rails.env.development?` block containing `namespace :dev do; resource :game, only: %i[show destroy]; end`; in production the routes simply do not exist, causing Rails to raise a routing error (404)
- `app/views/games/show.html.erb` — prepend conditional render of `_debug_bar` partial, guarded by `Rails.env.development? && session[:dev_game_id] == @game.id`
- `db/seeds.rb` — append `load Rails.root.join("db/seeds/feature_test_world.rb")` after the existing dungeon load

### 3. Implementation steps

1. **Create `db/seeds/feature_test_world.rb`**: use `World.find_or_create_by!(name: "QA Test World")` with a minimal valid world_data hash (meta with starting_room + at least one room). This must be created before the controller can reference it.

2. **Update `db/seeds.rb`**: add `load Rails.root.join("db/seeds/feature_test_world.rb")` after the existing `sample_dungeon.rb` load.

3. **Add routes in `config/routes.rb`**: inside `Rails.application.routes.draw` add at the bottom:
   ```ruby
   if Rails.env.development?
     namespace :dev do
       resource :game, only: %i[show destroy]
     end
   end
   ```

4. **Create `app/controllers/dev/game_controller.rb`**:
   - Define `DEV_USER_ID = 999_999` constant
   - Add `before_action :require_development!` raising `ActionController::RoutingError, "Not Found"` unless `Rails.env.development?` (defence-in-depth even though routes already guard this)
   - Override `current_user` to return an OpenStruct with `id: DEV_USER_ID, username: "Dev Player", is_owner?: false` when `session[:user_id] == DEV_USER_ID`, otherwise call `super`; this prevents `User.find` from raising `RecordNotFound` on the spoofed id
   - `show` action: set `session[:user_id] = DEV_USER_ID`; find `World.find_by(name: "QA Test World")`; render `missing_world` if nil; use `Game.find_or_create_by!(created_by: DEV_USER_ID, game_type: :classic)` passing `world:` on create via a block; store `session[:dev_game_id] = game.id`; redirect to `game_path(id: game.uuid)`
   - `destroy` action: find `Game.find_by(created_by: DEV_USER_ID, game_type: :classic)`; destroy if present; clear `session[:dev_game_id]`; redirect to `dev_game_path`

5. **Create `app/views/dev/game/missing_world.html.erb`**: display a clear error heading and the command `bin/rails db:seed` in a code block.

6. **Create `app/views/games/_debug_bar.html.erb`**: accept locals `game:` and `dev_user_id:`; read `player_state = game.player_state(dev_user_id)`; display room id, inventory (joined), flags (formatted); include `button_to "Reset Game", dev_game_path, method: :delete, class: "..."` ; wrap in a `fixed top-0` styled div.

7. **Update `app/views/games/show.html.erb`**: at the very top (before turbo_stream_from tags), add:
   ```erb
   <% if Rails.env.development? && session[:dev_game_id].present? && session[:dev_game_id] == @game.id %>
     <%= render "debug_bar", game: @game, dev_user_id: 999_999 %>
   <% end %>
   ```

### 4. Test plan

All tests in `test/controllers/dev/game_controller_test.rb` using `ActionDispatch::IntegrationTest`.

**Test: redirects to game and sets session**
- Setup: `World.find_or_create_by!(name: "QA Test World", ...)` in `setup` block
- Input: `get "/dev/game"`
- Expected: `assert_response :redirect`; `assert_match %r{/games/}, response.location`; `assert_equal 999_999, session[:user_id]`

**Test: reuses existing dev game (no duplicates)**
- Setup: QA world exists; call `get "/dev/game"` twice
- Expected: `assert_equal 1, Game.where(created_by: 999_999, game_type: "classic").count`

**Test: creates game when none exists**
- Setup: QA world exists; `Game.where(created_by: 999_999).destroy_all`
- Input: `get "/dev/game"`
- Expected: `assert_equal 1, Game.where(created_by: 999_999, game_type: "classic").count`

**Test: shows missing world error page**
- Setup: `World.where(name: "QA Test World").destroy_all`
- Input: `get "/dev/game"`
- Expected: `assert_response :ok`; `assert_match "bin/rails db:seed", response.body`

**Test: delete destroys dev game and redirects to /dev/game**
- Setup: QA world exists; `get "/dev/game"` to create dev game
- Input: `delete "/dev/game"`
- Expected: `assert_redirected_to "/dev/game"`; `assert_nil Game.find_by(created_by: 999_999, game_type: "classic")`

**Test: production guard raises routing error**
- Use `stub` on `Rails.env` to return `"production"` (or test the before_action raises RoutingError directly by calling `require_development!` on a controller instance with a stubbed env). Alternatively: verify the route does not exist by asserting the route helper `dev_game_path` is not defined when env is not development — but since tests run in test env (not production), we test the before_action guard directly.

### 5. Gotchas and constraints

- **`ApplicationController#current_user` calls `User.find`**: will raise `ActiveRecord::RecordNotFound` for id `999_999`. Must override `current_user` in `Dev::GameController` to intercept the spoofed id. Do not modify `ApplicationController`.
- **`check_for_setup` before_action**: calls `User.where(is_owner: true).any?`. In a fresh dev DB with no owner, this redirects to setup before the dev controller even runs. Acceptable behaviour per spec; developer must run setup once.
- **CanCan**: `Dev::GameController` does not call `load_resource` or `authorize_resource`, so no ability checks are performed — correct.
- **`setup_classic_game` callback**: fires `after_create_commit` only, so `find_or_create_by!` triggers it only on first create. The callback requires `world` to be set; pass it in the `find_or_create_by!` block: `Game.find_or_create_by!(created_by: DEV_USER_ID, game_type: :classic) { |g| g.world = world; g.name = "Dev Game" }`.
- **`game.host?`** in `games/show.html.erb` calls `created_by == user&.id`; our overridden `current_user` returns an object with `id == 999_999` and the game has `created_by == 999_999`, so the host view branch is taken — which is the desired behaviour.
- **`DEV_USER_ID`** must use numeric underscore (`999_999`) per RuboCop `Style/NumericLiterals`.
- **frozen_string_literal**: all new Ruby files must begin with `# frozen_string_literal: true`.
- **`button_to` CSRF**: `button_to` generates a form with a CSRF token automatically; no manual authenticity token needed.
- **Test isolation**: create and destroy the QA world and dev game within each test's setup/teardown (or use `after { Game.where(created_by: 999_999).destroy_all }`) to prevent fixture bleed. Do not rely on fixtures for World records since the fixtures have nil `world_data`.
- **`session[:dev_game_id]`** stores an Integer (AR id). Compare with `==` and store the raw id, not uuid.
