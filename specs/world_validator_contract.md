# Shared world validator contract

The Classic Game Engine and the world builder need to agree on what a valid
world is, without sharing code. Today `ClassicGame::Engine.validate_world_data`
only checks dice rolls, and the `World` model only checks that `world_data` is
present, so a world with a dangling room reference or a creature without
health saves fine and breaks at play time. The builder (a standalone HTML
page) has its own checks that can drift from the engine.

This feature makes the contract data, not code: a JSON Schema for shape, a
small reference table for cross-references, and a fixture corpus with stable
error codes that any implementation must reproduce. The Ruby side ships here.
The builder's JavaScript validator is a separate change that will consume the
same three files.

## Acceptance criteria

- `app/lib/classic_game/contract/world.schema.json` is a JSON Schema
  (draft 2020-12) for the world document. It covers: `meta` with required
  `name`, `description`, `starting_room` and optional `version`, `author`,
  `editor` (any object, never validated further); `rooms` with required
  `name` and `description`, `exits` as an object whose values are either a
  room id string or an exit object (`to` required), optional `items`,
  `npcs`, `creatures` arrays of strings, and `on_enter`; `items` with every
  documented field, including the enums `on_use.type` in unlock/message/heal,
  `combat_effect.type` = heal, `dice_roll.consume_on` in failure/success/any,
  and `dice_roll` requiring `dc`, `on_success`, `on_failure`; `npcs` with
  dialogue, topics, trade and movement (`movement` is a oneOf of patrol and
  triggered); `creatures` with `health` required and greater than 0, and
  `attack_condition` allowing exactly one of `moves`, `room_entries`,
  `on_talk`.
- Unknown keys are allowed everywhere except inside `attack_condition`, so
  existing worlds keep validating when new fields land. `attack_condition` is
  the one closed object because an unknown key there silently disables the
  creature.
- Engine defaults are recorded as `default` values in the schema where the
  engine has them: player max health 10, player base attack 5, creature
  `attack` 5, creature `defense` 0, `combat_effect.amount` 10, `dice` "1d20".
- `app/lib/classic_game/contract/world.refs.json` lists every id reference as
  `{ "path": "rooms.*.exits.*.to", "kind": "rooms" }`, using `*` for any key
  or index. It covers `meta.starting_room`, exit `to`, `requires`,
  `use_item`, room `items`/`npcs`/`creatures`, container `contents` and
  `unlock_item`, NPC `accepts_item`/`gives_item`, topic `requires_item`,
  creature `loot`, movement `schedule[].room`,
  `schedule[].blocked_while_player_in[]` and `destination`, and
  `dice_roll.*.unlocks_exit.room`. Flag fields are listed with
  `"kind": "flag"` and `"mode": "set"` or `"check"` so tooling can build a
  flag index from the same table. `leads_to` and `unlocks_dialogue.topic` use
  `"kind": "topic"` with `"scope": "npc"` or `"scope": "world"`.
- `ClassicGame::WorldValidator.new(world_data).errors` returns an array of
  `{ code:, path:, message: }` hashes. Codes are stable strings: at least
  `schema.invalid`, `starting_room.missing`, `ref.missing`, `topic.missing`,
  `dice.outcomes`, `dice.consume_on`, `attack_condition.invalid`. `path` is a
  dotted path into the document (`rooms.bridge.exits.west.to`).
- Schema errors come from the `json_schemer` gem evaluating the schema file.
  Reference errors come from walking the refs table; nothing about which
  fields reference what is hard-coded in Ruby.
- `ClassicGame::Engine.validate_world_data` delegates to the validator and
  keeps returning an array of message strings, so existing callers and tests
  are unchanged.
- `World` runs the validator on save and adds each error to
  `errors[:world_data]`, so the editor's save shows them.
- `test/fixtures/files/worlds/valid/*.json` and
  `test/fixtures/files/worlds/invalid/*.json` form the corpus. Every invalid
  fixture has a sibling `<name>.expected.json` holding the list of error
  codes it must produce, compared order-insensitively. The corpus contains
  The Tipsy Dragon (`games/the_tipsy_dragon.json`), the Crystal Quest from
  the docs, and at least one invalid fixture per error code.
- A test runs every fixture through `WorldValidator` and asserts the valid
  ones produce no errors and the invalid ones produce exactly their expected
  codes.
- All worlds in `games/` validate with zero errors.
- `site/bin/build` copies the schema, refs table and the fixture corpus to
  `site/public/contract/` so the builder can fetch them from the site, and
  the docs overview page links to them.
- RuboCop passes, the full suite passes, and
  `test/lib/classic_game/full_game_system_test.rb` still passes.

## Constraints

- The only new gem is `json_schemer`.
- `meta.editor` must never produce a validation error, whatever it holds.
- The contract covers what the engine requires. Authoring advice such as
  unreachable rooms, unplaced items, or flags that are never set stays in the
  builder and is out of scope here.

## Gotchas

- Exits are either a plain string or an object, so the exit schema is a
  `oneOf`. The `oneOf` must not match both branches for a string.
- Dialogue topic keys are free text; The Tipsy Dragon has a topic called
  "meaning of life". `leads_to` refers to those keys within the same NPC, so
  the refs walker needs the `scope: npc` rule rather than a global kind.
- Containers start closed unless `starts_closed` is `false`, and `locked`
  has no effect on a container that starts open. That combination is not a
  contract error (the builder warns about it); include it in a valid fixture
  so nobody "fixes" it later.
- `attack_condition` with an unknown key makes a creature never attack.
  The docs say only one of the three keys is evaluated, so an unknown key or
  more than one key is an `attack_condition.invalid` error.
- The only current caller of `validate_world_data` is `Game` at snapshot
  time (`app/models/game.rb`), passing string-keyed JSON. Keep that path
  working before touching anything else.
