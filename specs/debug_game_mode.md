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
