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
