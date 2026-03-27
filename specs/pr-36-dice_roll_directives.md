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
