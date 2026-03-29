> PR: https://github.com/Fishy49/supertextadventure/pull/36

# Dice Roll Directives

Dice rolls defined in the world JSON can specify branching outcomes — one for
success, one for failure. This ensures players are never deadlocked: a failed
roll always opens an alternative path rather than a dead end.

There already exists a dice-rolling mechanism that should be triggerable.
The game should enter a "Roll" state where the user has to roll a dice by typing "ROLL 1d20" or whatever the roll requires.

## Player-facing behaviour

### Succeed a roll — door unlocks
```
> pick lock
You attempt to pick the lock... Roll to determine outcome.
> roll
You rolled a 15. Success!
```

### Fail a roll — alternative path opens
```
> pick lock
You attempt to pick the lock... [roll: 5 vs DC 12] Failed.
You scratch up the lock badly. Maybe the guard captain would know another way in.
```
(The `talk to guard captain about door` topic is now unlocked.)

---

## World data format

```json
"pick_lock": {
  "dc": 12,
  "stat": "dexterity",
  "on_success": {
    "sets_flag": "north_door_unlocked",
    "message": "The lock clicks open. The door swings wide."
  },
  "on_failure": {
    "unlocks_dialogue": { "npc": "guard_captain", "topic": "door" },
    "message": "You scratch up the lock badly. Maybe the guard captain would know another way in."
  }
}
```

Both `on_success` and `on_failure` are **required** — a dice roll directive
without both branches is invalid world data.

---

## Acceptance criteria

- A dice roll in world JSON may include `on_success` and `on_failure` directive
  blocks
- On a successful roll, the `on_success` directive executes (e.g. sets a flag,
  unlocks an exit, gives an item)
- On a failed roll, the `on_failure` directive executes (e.g. opens a dialogue
  topic, sets a different flag, describes an alternative path)
- Both branches must be present; a roll with only one branch is rejected with a
  clear error at world-load time
- The player always receives the appropriate `message` from the matching branch
- Common directive actions supported in both branches: `sets_flag`,
  `unlocks_dialogue` (npc + topic), `unlocks_exit`

## Constraints

- No deadlocks: game authors cannot define a roll where failure produces no
  forward progress
- Directive actions are the same set supported elsewhere in the engine (flags,
  dialogue, exits) — no new action types introduced by this feature

---

## Implementation plan

> Generated 2026-03-27

### 1. Files to create

| File | Purpose |
|------|---------|
| `app/lib/classic_game/handlers/roll_handler.rb` | Handler for the `roll` verb — resolves a pending dice roll against DC, executes the matching branch directives, and returns the outcome message. |
| `test/lib/classic_game/handlers/roll_handler_test.rb` | Tests for RollHandler covering success, failure, directive actions, validation, and edge cases. |

### 2. Files to modify

| File | Changes |
|------|---------|
| `app/lib/classic_game/command_parser.rb` | Add `:roll` verb to the `VERBS` hash (synonyms: `%w[roll]`). Add `:roll` to the no-argument verb list in `extract_parts` so it parses like `:inventory`. |
| `app/lib/classic_game/engine.rb` | (a) Add a new priority intercept at the top of `execute`: if `player_state` has a `"pending_roll"` hash, route **all** input to `RollHandler` (similar to the `pending_restart` pattern). (b) Add `:roll` to the `get_handler` case statement, mapping to `ClassicGame::Handlers::RollHandler`. |
| `app/lib/classic_game/base_handler.rb` | Add two protected helpers: `execute_roll_directives(branch)` — processes `sets_flag`, `unlocks_dialogue`, and `unlocks_exit` from a directive branch hash; `pending_roll?` — returns whether the player has an active pending roll. |
| `app/lib/classic_game/handlers/item_handler.rb` | In `handle_use`, after finding the item and before any `on_use` processing: if the item definition contains a `"dice_roll"` key, validate both branches exist, set `pending_roll` on player state with the roll spec, and return the attempt message instead of executing the normal use flow. |
| `test/lib/classic_game/command_parser_test.rb` | Add a test for the `roll` verb parsing. |
| `test/support/classic_game_helper.rb` | Add an `unlock_dialogue(npc_id, topic_id)` convenience method on `FakeGame` that calls `set_flag("dialogue_unlocked_#{topic_id}", true)` — useful for asserting unlocks_dialogue directive results. |

### 3. Implementation steps

**Step 1 — Add `roll` verb to CommandParser**

In `app/lib/classic_game/command_parser.rb`:
- Add `roll: %w[roll]` to the `VERBS` hash, inside the `# Special` group (after `restart`).
- Add `:roll` to the `when :inventory, :help, :save, :quit, :restart, :defend, :flee` branch in `extract_parts` so it returns `[verb, nil, nil]`.

**Step 2 — Add `pending_roll?` and `execute_roll_directives` helpers to BaseHandler**

In `app/lib/classic_game/base_handler.rb`, add two new protected methods:

- `pending_roll?` — returns `player_state["pending_roll"].present?`.
- `execute_roll_directives(branch, room_id)` — iterates over the directive keys in the branch hash:
  - `"sets_flag"` — calls `game.set_flag(value, true)`.
  - `"unlocks_dialogue"` — reads `npc` and `topic` from the sub-hash, calls `game.set_flag("dialogue_unlocked_#{topic}", true)`.
  - `"unlocks_exit"` — reads `room` (defaults to `room_id`) and `direction`, calls `game.unlock_exit(room, direction)`.

**Step 3 — Create RollHandler**

Create `app/lib/classic_game/handlers/roll_handler.rb`:

```
ClassicGame::Handlers::RollHandler < BaseHandler
```

`handle(command)`:
1. Guard: return `failure("Nothing to roll for.")` unless `pending_roll?`.
2. Read `roll_spec = player_state["pending_roll"]` — contains `"dc"`, `"stat"`, `"dice"` (default `"1d20"`), `"on_success"`, `"on_failure"`, `"source_item"`.
3. Parse the dice notation from `roll_spec["dice"] || "1d20"` using the existing `DiceRoll` class: `result = DiceRoll.new(roll_spec["dice"] || "1d20")`.
4. Compare `result.total` against `roll_spec["dc"]`.
5. Select the winning branch: `branch = result.total >= dc ? roll_spec["on_success"] : roll_spec["on_failure"]`.
6. Call `execute_roll_directives(branch, player_state["current_room"])`.
7. Clear `pending_roll` from player state.
8. Build the response: `"You rolled a #{result.total}. #{result.total >= dc ? 'Success!' : 'Failed.'}\n#{branch['message']}"`.
9. Return `success(response_text)`.

**Step 4 — Wire RollHandler into Engine**

In `app/lib/classic_game/engine.rb`, method `execute`:
- After the `pending_restart` check (line 8) and before `CommandParser.parse`, add:
  ```ruby
  player_state = game.player_state(user.id)
  if player_state["pending_roll"]
    return ClassicGame::Handlers::RollHandler.new(game: game, user_id: user.id).handle(
      ClassicGame::CommandParser.parse(command_text)
    )
  end
  ```
  This ensures that while a roll is pending, any input (even non-"roll" commands) is routed to the RollHandler, which will reject non-roll input with a prompt.

- In the `get_handler` case statement, add:
  ```ruby
  when :roll
    ClassicGame::Handlers::RollHandler
  ```

Actually, refine the RollHandler `handle` method: if `pending_roll?` is true but the verb is not `:roll`, return `failure("You need to ROLL first. Type ROLL to roll the dice.")`. If `pending_roll?` is false and verb is `:roll`, return `failure("Nothing to roll for.")`.

**Step 5 — Add dice roll trigger to ItemHandler**

In `app/lib/classic_game/handlers/item_handler.rb`, in `handle_use`, after verifying the player has the item (line 87), add a new check before the `reveals_exit` check (line 96):

```ruby
# Check if item triggers a dice roll
if item_def["dice_roll"]
  return handle_dice_roll_trigger(item_id, item_def)
end
```

Add private method `handle_dice_roll_trigger(item_id, item_def)`:
1. Read `roll_data = item_def["dice_roll"]`.
2. Validate both branches: `return failure("Invalid world data: dice roll missing on_success or on_failure.")` unless `roll_data["on_success"] && roll_data["on_failure"]`.
3. Set `pending_roll` on player state:
   ```ruby
   new_state = player_state.dup
   new_state["pending_roll"] = roll_data.merge("source_item" => item_id)
   update_player_state(new_state)
   ```
4. Build attempt message: `roll_data["attempt_message"] || "You attempt the action... Roll to determine the outcome."`.
5. Append: `"\nType ROLL to roll the dice."`.
6. Return `success(attempt_message)`.

**Step 6 — Add world-load validation for dice_roll branches**

In `app/lib/classic_game/engine.rb`, add a class method `validate_world_data(world_data)` that iterates all items in `world_data["items"]` and for any item with a `"dice_roll"` key, checks that both `"on_success"` and `"on_failure"` are present hashes. Returns an array of error strings. This can be called at game setup time.

In `Game#setup_classic_game` (in `app/models/game.rb`), after snapshotting the world, call `ClassicGame::Engine.validate_world_data(world_snapshot)` and raise if errors are found. This fulfills the acceptance criterion "a roll with only one branch is rejected with a clear error at world-load time."

**Step 7 — Write tests**

See Test Plan below.

### 4. Test plan

All tests go in `test/lib/classic_game/handlers/roll_handler_test.rb`. They use `ClassicGameTestHelper` and `FakeGame`.

#### Test: "roll command parses correctly"
- **File**: `test/lib/classic_game/command_parser_test.rb`
- **Input**: `"roll"`
- **Expected**: `{ verb: :roll, target: nil }`

#### Test: "successful roll sets flag and returns success message"
- **Setup**: World with item `"lockpick"` having `dice_roll: { dc: 10, stat: "dexterity", on_success: { sets_flag: "door_unlocked", message: "The lock clicks open." }, on_failure: { message: "You fail.", sets_flag: "lock_jammed" } }`. Player has `lockpick` in inventory. Player has `pending_roll` already set (simulating post-use state).
- **Input**: `"roll"`
- **Mock**: Stub `DiceRoll` or `rand` to produce a total >= 10.
- **Expected**: Response includes "Success!" and "The lock clicks open.". Flag `"door_unlocked"` is set. `pending_roll` cleared from player state.

#### Test: "failed roll executes on_failure directive and returns failure message"
- **Setup**: Same world. `pending_roll` set with DC 15.
- **Input**: `"roll"`
- **Mock**: Stub to produce total < 15.
- **Expected**: Response includes "Failed." and the failure message. Failure flag/directive is executed. `pending_roll` cleared.

#### Test: "roll with unlocks_dialogue directive sets dialogue flag"
- **Setup**: `on_failure: { unlocks_dialogue: { npc: "guard_captain", topic: "door" }, message: "..." }`. Pending roll set, roll fails.
- **Input**: `"roll"`
- **Expected**: `game.get_flag("dialogue_unlocked_door")` is truthy.

#### Test: "roll with unlocks_exit directive unlocks the exit"
- **Setup**: `on_success: { unlocks_exit: { direction: "north" }, message: "..." }`. Pending roll set, roll succeeds.
- **Input**: `"roll"`
- **Expected**: `game.exit_unlocked?(current_room, "north")` is true.

#### Test: "non-roll command while roll is pending returns prompt to roll"
- **Setup**: Player has `pending_roll` set.
- **Input**: `"go north"`
- **Expected**: Response includes "You need to ROLL first".

#### Test: "roll with no pending roll returns nothing to roll for"
- **Setup**: No `pending_roll` on player state.
- **Input**: `"roll"`
- **Expected**: `success: false`, response includes "Nothing to roll for."

#### Test: "using item with dice_roll sets pending_roll and returns attempt message"
- **Setup**: Item `"lockpick"` with `dice_roll` data in world. Player has `lockpick` in inventory.
- **Input**: `"use lockpick"`
- **Expected**: `success: true`, response includes "Roll to determine the outcome" and "Type ROLL". Player state now has `pending_roll`.

#### Test: "item with dice_roll missing on_failure is rejected"
- **Setup**: Item with `dice_roll: { dc: 10, on_success: { ... } }` (no `on_failure`).
- **Input**: `"use lockpick"`
- **Expected**: `success: false`, response includes "Invalid world data".

#### Test: "player always receives the message from the matching branch"
- **Setup**: Two different messages in success vs failure branches. Run twice, once succeeding, once failing.
- **Expected**: Each run returns exactly the message from its branch.

### 5. Gotchas and constraints

- **Follow the `pending_restart` pattern exactly.** The engine already has a priority-intercept pattern for `pending_restart` (line 8 of `Engine.execute`). The `pending_roll` intercept should be structured identically — check before parsing, route to handler, let handler decide validity.

- **RuboCop rules to respect:**
  - `Style/StringLiterals: double_quotes` — all strings must use double quotes.
  - `Metrics/MethodLength: Max 60` — keep handler methods under 60 lines.
  - `Layout/IndentationConsistency: indented_internal_methods` — private/protected methods indented one extra level inside the class body (matching all existing handlers).
  - `# frozen_string_literal: true` at top of every Ruby file.

- **DiceRoll class expects a string like `"1d20"`.** It uses `scan(/(\d{1,2}d\d{1,2})|([-+]\d{1,2})/)` to parse. The `dice_roll` world data should default to `"1d20"` if no dice notation is specified, so `DiceRoll.new(roll_spec["dice"] || "1d20")` is correct.

- **FakeGame in tests does not call `save!` with real persistence.** The `set_flag`, `unlock_exit` etc. methods on FakeGame modify in-memory state, which is sufficient. The `unlock_dialogue` convenience helper should be added to FakeGame for test readability.

- **`execute_roll_directives` must handle all three action types idempotently.** `sets_flag` calls `game.set_flag(name, true)`. `unlocks_dialogue` calls `game.set_flag("dialogue_unlocked_#{topic}", true)` — this mirrors `InteractHandler#handle_talk_topic` line 96. `unlocks_exit` calls `game.unlock_exit(room, direction)` — this mirrors `ItemHandler#handle_use_on_exit` line 271.

- **The `pending_roll` hash stored on player state must include the full roll spec** (dc, on_success, on_failure, optional dice notation, source_item). This is cleared after the roll resolves, regardless of outcome.

- **World validation happens at game setup time** (in `Game#setup_classic_game`), not at World save time. This keeps the World model simple and catches errors only when a game is actually created from invalid world data.

- **No new "action types" are introduced.** The directives `sets_flag`, `unlocks_dialogue`, and `unlocks_exit` already exist in the engine (used by InteractHandler, ItemHandler, CombatHandler). The roll handler just reuses the same game state mutation methods.

- **The spec mentions a "Roll state" where the user types "ROLL 1d20".** For simplicity, the implementation should accept bare `ROLL` (the dice notation comes from the world data, not the player). The pending_roll spec already knows which dice to roll. This avoids parsing issues and keeps the player experience simple.

- **Edge case: player dies or restarts while a roll is pending.** The `pending_restart` check in Engine.execute happens before the `pending_roll` check, so restart always takes priority. If the game is fully reset, `pending_roll` is cleared along with all player state.
