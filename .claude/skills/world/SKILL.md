---
name: world
description: Build, inspect, validate, and play-test Classic Game Engine worlds with bin/world instead of hand-editing world JSON.
argument-hint: [path/to/world.json]
allowed-tools: Bash(bin/world *), Read
---

# World CLI

`bin/world` is the tool for creating and changing Classic Game Engine worlds
(the JSON files in `games/` and the `world_data` of World records). Use it
instead of editing the JSON directly: every edit writes the file, then prints
what changed and what the validator found, and `play` runs the world through
the real engine so you can prove a puzzle works.

The loop:

1. `bin/world check FILE` to see errors, warnings, and infos.
2. Edit with the commands below (or `apply` a batch).
3. `bin/world check FILE` again until it reports 0 errors and 0 warnings.
4. Write a walkthrough script and run `bin/world play FILE --script WALK.txt`
   until every expectation passes.

Add `--json` to any command for machine-readable output. Exit codes: 0 ok,
1 the world has errors or a script failed, 2 bad usage or a refused edit.

## Commands

| Command | What it does |
| --- | --- |
| `new FILE [--name N] [--description T]` | Create a world with one starting room |
| `check FILE [--strict]` | Contract errors plus lint warnings and infos |
| `show FILE [PATH]` | Summary, or the JSON at a dotted path such as `rooms.cellar.exits` |
| `ls FILE SECTION [--in ROOM]` | List `rooms`, `items`, `npcs`, `creatures`, or `flags` with placements |
| `graph FILE` | Every room and its exits, with locks and hidden exits marked |
| `refs FILE ID` | Every path that references an id |
| `add FILE SECTION ID [--name N] [--description T] [--in ROOM]` | Add an entity skeleton, optionally placed |
| `set FILE PATH VALUE` | Set a dotted path. VALUE is parsed as JSON (`true`, `3`, `["a","b"]`, `{"to":"hall"}`), otherwise kept as a string |
| `del FILE PATH` | Delete a dotted path |
| `rename FILE SECTION ID NEW_ID` | Rename an entity and every reference to it |
| `rm FILE SECTION ID` | Remove an entity and every reference to it |
| `link FILE ROOM DIRECTION TARGET [--both]` | Add or retarget an exit; `--both` adds the way back |
| `unlink FILE ROOM DIRECTION` | Remove an exit |
| `place FILE ID TARGET` | Move an item, npc, or creature into a room, or an item into a container |
| `unplace FILE ID` | Take an entity out of every room and container |
| `apply FILE [OPS.json or -]` | Apply a JSON array of operations in one call |
| `play FILE [--script F] [--commands "a; b"] [--seed N]` | Play headlessly; with no input flags it reads stdin, or prompts on a terminal |
| `explain [CODE]` | What a check code means and how to fix it |

Sections are `rooms`, `items`, `npcs`, `creatures`. Ids are keys inside those
sections and cannot contain dots or spaces. Paths are dotted and may index
arrays: `rooms.cellar.items.0`.

## Batches

`apply` takes an array of objects with an `op` and the same parameters as the
command line. Twenty edits in one process beats twenty boots.

```json
[
  { "op": "add", "section": "rooms", "id": "hall", "name": "The Hall", "description": "Long and dim." },
  { "op": "link", "room": "start", "direction": "north", "to": "hall", "both": true },
  { "op": "add", "section": "items", "id": "key", "in": "hall" },
  { "op": "set", "path": "rooms.hall.exits.east", "value": { "to": "vault", "use_item": "key" } },
  { "op": "rename", "section": "items", "id": "key", "new_id": "brass_key" },
  { "op": "place", "id": "brass_key", "in": "chest" },
  { "op": "rm", "section": "rooms", "id": "attic" }
]
```

## Walkthrough scripts

One command per line. Blank lines and `#` comments are ignored. `expect`
lines check the game instead of playing it, and `not` flips any check.

```
take rusty key
expect has rusty_key
north
expect room hall
expect flag door_open
expect not flag dragon_dead
expect health >= 5
expect says the door swings open
```

`play` prints the transcript, each expectation's result, and the final state
(room, inventory, health, flags, turns). Dice and combat are seeded (default
seed 1) so a script gives the same result every run; pass `--seed` to try
another. Shipped games keep their walkthrough at `games/NAME.walkthrough.txt`
and `ClassicGame::WalkthroughTest` runs them, so a shipped world that cannot
be finished fails the suite.

## Reading the check output

Errors break the contract and the engine refuses the world. Warnings mean
the world validates but something cannot work: an unreachable room, an item
nobody can obtain, a lock with no key, a flag that is checked but never set.
Infos are advisory. `bin/world explain CODE` gives the meaning and the fix for
any code.

The same checks run in the browser World Builder and in the Rails model, from
the shared contract in `app/lib/classic_game/contract/`.
