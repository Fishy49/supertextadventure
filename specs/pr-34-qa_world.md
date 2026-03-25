> PR: https://github.com/Fishy49/supertextadventure/pull/34

# Full-Featured QA World

Replace the current bare-bones QA Test World (a single empty room) with a
rich, self-contained world that exercises **every game engine capability** in
one compact map. Developers hit `/dev/game` and immediately have a playground
for manual QA; system tests use the same world to verify end-to-end behaviour.

---

## Player-facing behaviour

The developer visits `/dev/game` and lands in a small but feature-complete
world. Every engine capability is reachable within a few commands.

### Map layout (5 rooms)

```
                  [tower_top]
                      |
[market] -- [town_square] -- [tavern]
                      |
                  [cave]
```

- **town_square** — Starting room. Has an NPC (town crier) and a takeable
  item (rusty_key). Exits in all four directions.
- **tavern** — Contains the innkeeper NPC with a full dialogue tree
  (greeting, topics, flag-gated topic, item-gated topic, `leads_to` chain).
  A locked container (chest) that requires `rusty_key` to open, containing a
  health_potion (consumable).
- **market** — Contains a merchant NPC who accepts an item (gem) and gives a
  reward (enchanted_sword, weapon). Demonstrates the give-item-to-NPC flow.
- **cave** — Contains a creature (cave_spider) for combat testing. A hidden
  exit to a secret alcove revealed by a flag. Contains a shield (defense item).
- **tower_top** — Locked exit from town_square, unlocked by a flag set
  during dialogue. Contains the gem item needed for the merchant trade.

### Capabilities covered

| Capability              | Where exercised                              |
|-------------------------|----------------------------------------------|
| Movement (all dirs)     | town_square exits N/S/E/W                    |
| Look / examine          | Every room has a description + items          |
| Take / drop items       | rusty_key in town_square, gem in tower_top   |
| Inventory management    | Carry items between rooms                     |
| Locked exits            | tower_top exit (flag-gated)                  |
| Hidden/revealed exits   | cave secret alcove (flag-gated reveal)       |
| Open/close containers   | chest in tavern (key-gated)                  |
| Consumable items        | health_potion (restores health)              |
| Weapons & defense       | enchanted_sword (weapon), shield (defense)   |
| NPC greeting            | talk to crier / innkeeper                    |
| NPC topic dialogue      | talk to innkeeper about rooms                |
| NPC flag-gated topic    | innkeeper topic requires `spoke_to_crier`    |
| NPC item-gated topic    | innkeeper topic requires rusty_key           |
| NPC leads_to chain      | innkeeper topics chain: rooms -> tower       |
| NPC sets_flag           | crier sets `spoke_to_crier` flag             |
| NPC give/receive items  | give gem to merchant -> receive enchanted_sword |
| Combat (attack/defend/flee) | cave_spider in cave                      |
| Creature drops          | cave_spider drops shield on defeat           |
| Global flags            | spoke_to_crier, tower_unlocked, spider_slain |
| Restart                 | Always available                              |

---

## Constraints

- The QA world replaces the current minimal `QA Test World` — same name, same
  lookup. No second world is created.
- World data lives in a single method (`create_qa_world` in
  `SystemTestHelper` and the `qa_test_world` fixture) so there is exactly one
  source of truth that both dev mode and tests use.
- Extract the world data hash into a shared module (e.g.
  `TestSupport::QaWorldData`) that the fixture template, `create_qa_world`,
  and seeds can all reference.
- Keep the world small — 5 rooms max. The goal is coverage, not scale.
- Every item, NPC, and creature must have `keywords` for parser matching.

---

## Acceptance criteria

- `/dev/game` loads the full-featured QA world (not the old empty room)
- The QA world contains at least 5 rooms connected by exits in cardinal
  directions
- At least 2 NPCs with dialogue trees (including flag-gated and item-gated
  topics, and a `leads_to` chain)
- At least 1 NPC that accepts an item and gives a reward
- At least 1 locked exit that can be unlocked via a flag
- At least 1 hidden exit that is revealed via a flag
- At least 1 locked container that requires a key item to open
- At least 1 consumable item, 1 weapon, and 1 defense item
- At least 1 creature that can be fought and drops loot
- System tests exist that exercise each capability listed above through the
  browser (via `/dev/game`)
- All existing system tests continue to pass
- `bin/rails test:system` passes on a clean checkout

### System tests

All tests use `/dev/game` and run through the browser with Capybara + Cuprite.

#### Navigation (`test/system/qa_world/navigation_test.rb`)
- Move in all four directions from town_square and arrive at the correct rooms
- Attempt to move through a locked exit and see a rejection message
- Unlock the exit (via flag) and move through successfully

#### Items (`test/system/qa_world/items_test.rb`)
- Take rusty_key from town_square, confirm it appears in inventory
- Drop an item and confirm it appears in room description
- Use health_potion and confirm health restored / item consumed

#### Containers (`test/system/qa_world/containers_test.rb`)
- Attempt to open chest without key, see rejection
- Open chest with rusty_key in inventory, see contents

#### NPC Dialogue (`test/system/qa_world/dialogue_test.rb`)
- Talk to crier, receive greeting, flag `spoke_to_crier` set
- Talk to innkeeper about a base topic
- Attempt flag-gated topic before flag is set, see locked_text
- Set flag via crier, then access gated topic successfully
- Follow a `leads_to` topic chain

#### NPC Item Exchange (`test/system/qa_world/exchange_test.rb`)
- Give gem to merchant, receive enchanted_sword
- Attempt to give wrong item, see rejection

#### Combat (`test/system/qa_world/combat_test.rb`)
- Enter cave, attack cave_spider, see combat feedback
- Defeat spider, see loot drop (shield)
- Test flee to exit combat and return to previous room

#### Gotchas

- The fixture file uses ERB (`<%= ... .to_json %>`) for the `world_data`
  column. The shared data module must return a plain Ruby hash so both the
  fixture ERB and the helper can use it.
- The debug bar reads from `game_state`, not `world_data`. Make sure the
  engine initialises state correctly for rooms with locked/hidden exits.
- Consumable items need a `consumable` key with `effect` and `amount` — check
  that `ItemHandler` supports this before assuming it works.
- Container `open` requires the key item in inventory — verify
  `ContainerHandler` checks inventory, not room items.

---

## Implementation plan

> Generated 2026-03-25

### 1. Files to create

| File | Purpose |
|------|---------|
| `test/support/qa_world_data.rb` | Shared module `TestSupport::QaWorldData` that returns the full QA world hash via `.data`. Single source of truth for fixture, helper, and seeds. |
| `test/system/qa_world/navigation_test.rb` | System tests for movement, locked exits, hidden exits. |
| `test/system/qa_world/items_test.rb` | System tests for take, drop, use (consumable). |
| `test/system/qa_world/containers_test.rb` | System tests for locked container open/close. |
| `test/system/qa_world/dialogue_test.rb` | System tests for NPC talk, topics, flag-gated topics, leads_to chains. |
| `test/system/qa_world/exchange_test.rb` | System tests for give-item-to-NPC flow. |
| `test/system/qa_world/combat_test.rb` | System tests for attack, defeat + loot, flee. |

### 2. Files to modify

| File | Changes |
|------|---------|
| `app/lib/classic_game/handlers/interact_handler.rb` | **`handle_talk`**: Extend to support topic-based dialogue. Currently only returns `dialogue["default"]`. Must: (1) Fall back to `command[:modifier]` when `command[:target]` is blank (because `talk to X` puts NPC in modifier due to `extract_target_and_modifier` splitting on "to"); (2) Accept `command[:modifier]` as a topic name when the target is the NPC (i.e. `talk to innkeeper about rooms` currently parses as target="" modifier="innkeeper about rooms" — rework to parse NPC + topic out of that); (3) Look up topic in `dialogue["topics"][topic_name]`; (4) Check `requires_flag` / `requires_item` on topics and show `locked_text` when unmet; (5) Handle `sets_flag` on greeting; (6) Handle `leads_to` to return follow-up topic hints. Also add a new private method `handle_talk_topic(npc_id, npc_def, topic_name)`. |
| `app/lib/classic_game/handlers/item_handler.rb` | **`handle_use`**: Add a `"heal"` case to `on_use["type"]` so consumable items work outside combat. When type is `"heal"`, increase player health by `on_use["amount"]`, cap at `max_health`, remove item from inventory if `item_def["consumable"]` is true, and return a success message. |
| `test/support/qa_world_data.rb` | (New file — see section 1.) |
| `test/support/system_test_helper.rb` | **`create_qa_world`**: Replace the inline minimal world hash with `TestSupport::QaWorldData.data`. Require the new `qa_world_data.rb` file at top. |
| `test/fixtures/worlds.yml` | **`qa_test_world`**: Replace inline JSON with `<%= TestSupport::QaWorldData.data.to_json %>`. Add a `require` comment at the top or use ERB to load the module. |
| `test/fixtures/games.yml` | **`classic_open`**: Update `game_state.world_snapshot` to use `TestSupport::QaWorldData.data` so the fixture's snapshot matches the new world. |
| `db/seeds/feature_test_world.rb` | Replace the inline minimal world hash with `TestSupport::QaWorldData.data`. Require the shared module at top. |
| `test/system/classic_game_test.rb` | Update `"initial room description"` assertion from `"Test Chamber"` to `"Town Square"` (new starting room name). Update `"navigation command with no exits"` — town_square now has exits in all four directions, so `go north` will succeed. Change to test an invalid direction like `go northeast`. Update `"reset game"` assertion from `"Test Chamber"` to `"Town Square"`. |

### 3. Implementation steps

**Step 1 — Create `test/support/qa_world_data.rb`**

Define `TestSupport::QaWorldData.data` returning a frozen hash with:

- **`meta`**: `starting_room: "town_square"`, version, author.
- **`rooms`** (5 rooms):
  - `town_square`: name "Town Square", description mentioning a bustling square, exits `{ north: "tower_top", south: "cave", east: "tavern", west: "market" }` where north is a complex exit `{ to: "tower_top", requires_flag: "tower_unlocked", locked_msg: "The tower gate is locked." }`. Items: `["rusty_key"]`. NPCs: `["crier"]`. No creatures.
  - `tavern`: name "The Tavern", description of a cozy inn. Exits: `{ west: "town_square" }`. Items: `["chest"]`. NPCs: `["innkeeper"]`.
  - `market`: name "The Market", description of stalls. Exits: `{ east: "town_square" }`. NPCs: `["merchant"]`. No items/creatures.
  - `cave`: name "The Cave", description of a dark cave. Exits: `{ north: "town_square", east: { to: "alcove", hidden: true, requires_flag: "spider_slain", reveal_msg: "With the spider defeated, you notice a narrow passage to the east." } }`. Creatures: `["cave_spider"]`.
  - `tower_top`: name "Tower Top", description of a high vantage point. Exits: `{ south: "town_square" }`. Items: `["gem"]`.
- Add a hidden room `alcove` (6th "room" but really a sub-area of cave): name "Secret Alcove", exits `{ west: "cave" }`, items: `["shield"]`. (Note: spec says 5 rooms max. We can treat alcove as part of cave, but it needs to be a separate room entry. Actually the map shows exactly 5 rooms. We should put the shield directly in the cave as a room item, or have the spider drop it. The spec says cave "Contains a shield (defense item)" AND spider drops shield — the spider drops the shield on defeat, so the shield is NOT a room item. The alcove can be omitted. The hidden exit can reveal a passage to `alcove` but let's keep alcove minimal or skip it. Actually re-reading: "A hidden exit to a secret alcove revealed by a flag." So alcove IS a room. But the spec says 5 rooms max. Resolution: the 5 rooms in the map are town_square, tavern, market, cave, tower_top. The alcove is a bonus sub-room. The spec says "5 rooms max" in constraints but also describes the alcove. We'll include alcove as a 6th room since the spec explicitly requires a hidden exit. Alternatively, make the hidden exit go from cave back to town_square via a secret path. But the spec explicitly says "secret alcove". Let's include it — the constraint "5 rooms max" is about the main map; the alcove is effectively a pocket room.)
  - `alcove`: name "Secret Alcove", description of a small hidden chamber. Exits: `{ west: "cave" }`. Items: `["shield"]`.
- **`items`**:
  - `rusty_key`: name "Rusty Key", keywords `["key", "rusty"]`, takeable true, description "An old rusty iron key."
  - `chest`: name "Wooden Chest", keywords `["chest"]`, is_container true, starts_closed true, locked true, unlock_item "rusty_key", locked_message "The chest is locked. It looks like it needs a key.", contents `["health_potion"]`, on_open_message "You unlock the chest with the rusty key and open it."
  - `health_potion`: name "Health Potion", keywords `["potion", "health"]`, takeable true, consumable true, description "A bubbling red potion.", on_use `{ type: "heal", amount: 5, text: "You drink the health potion and feel revitalized!" }`, combat_effect `{ type: "heal", amount: 5 }`.
  - `gem`: name "Sparkling Gem", keywords `["gem", "sparkling"]`, takeable true, description "A brilliant gemstone that glows faintly."
  - `enchanted_sword`: name "Enchanted Sword", keywords `["sword", "enchanted"]`, takeable true, weapon_damage 8, description "A sword that hums with magical energy."
  - `shield`: name "Iron Shield", keywords `["shield", "iron"]`, takeable true, defense_bonus 3, description "A sturdy iron shield."
- **`npcs`**:
  - `crier`: name "Town Crier", keywords `["crier", "town crier"]`, description "A loud man in official garb.", dialogue `{ default: "Hear ye! The innkeeper at the tavern knows many secrets. The tower is locked by ancient magic!", sets_flag: "spoke_to_crier" }`.
  - `innkeeper`: name "Innkeeper", keywords `["innkeeper", "keeper"]`, description "A jovial woman behind the bar.", dialogue with `default` greeting and `topics` hash:
    - `rooms`: `{ text: "There are five main areas...", leads_to: "tower" }` (base topic, always available)
    - `tower`: `{ text: "The tower can be unlocked... I've done it for you.", requires_flag: "spoke_to_crier", locked_text: "The innkeeper eyes you suspiciously. 'I don't share secrets with strangers. Perhaps the town crier can vouch for you.'", sets_flag: "tower_unlocked" }` (flag-gated topic)
    - `supplies`: `{ text: "Ah, you have the key! The chest in the corner holds a potion.", requires_item: "rusty_key", locked_text: "The innkeeper glances at the chest. 'That chest needs a special key to open.'" }` (item-gated topic)
  - `merchant`: name "Merchant", keywords `["merchant", "trader"]`, description "A shrewd-looking trader.", accepts_item "gem", gives_item "enchanted_sword", accept_message "The merchant's eyes light up! 'A gem! Here, take this enchanted sword in return.'", dialogue `{ default: "Looking to trade? I'm after a sparkling gem. Bring me one and I'll make it worth your while." }`.
- **`creatures`**:
  - `cave_spider`: name "Cave Spider", keywords `["spider", "cave spider"]`, description "A giant spider lurking in the shadows.", health 8, attack 3, defense 1, loot `["shield"]`, on_defeat_msg "The cave spider crumples to the ground!", on_flee_msg "The spider hisses as you retreat.", sets_flag_on_defeat "spider_slain".

**Step 2 — Update `InteractHandler#handle_talk` to support topics**

In `app/lib/classic_game/handlers/interact_handler.rb`, rewrite `handle_talk`:

```ruby
def handle_talk(command)
  target = command[:target]
  modifier = command[:modifier]

  # "talk to X" parses as target="" modifier="X"
  # "talk to X about Y" parses as target="" modifier="X about Y"
  npc_name, topic_name = resolve_talk_target(target, modifier)

  return failure("Talk to whom?") if npc_name.blank?

  npc_id, npc_def = find_npc(npc_name)
  return failure("You don't see anyone like that here.") unless npc_def
  return failure("You don't see anyone like that here.") unless npc_in_room?(npc_id)

  dialogue = npc_def["dialogue"]
  return failure("#{npc_def['name']} doesn't seem interested in talking.") unless dialogue

  if topic_name.present?
    handle_talk_topic(npc_def, dialogue, topic_name)
  else
    handle_talk_greeting(npc_def, dialogue)
  end
end
```

Change the method signature of `handle` so it passes the full command:
```ruby
when :talk
  handle_talk(command)
```

Add private methods:
- `resolve_talk_target(target, modifier)` — splits the NPC name from the topic. If target is present and non-blank, use target as NPC name, modifier as topic. If target is blank and modifier present, split modifier on " about " to get NPC name and optional topic.
- `handle_talk_greeting(npc_def, dialogue)` — returns default greeting text. If dialogue has `sets_flag`, set it.
- `handle_talk_topic(npc_def, dialogue, topic_name)` — looks up `dialogue["topics"][topic_name]`. Checks `requires_flag` (returns `locked_text` if flag not set). Checks `requires_item` (returns `locked_text` if item not in inventory). If checks pass, returns topic text. If topic has `sets_flag`, set it. If topic has `leads_to`, append a hint like "You could ask about [leads_to topic]."

**Step 3 — Update `ItemHandler#handle_use` to support consumable healing outside combat**

In `app/lib/classic_game/handlers/item_handler.rb`, add a `"heal"` case to the `on_use["type"]` switch in `handle_use`:

```ruby
when "heal"
  handle_heal(item_id, item_def, use_action)
```

Add private method `handle_heal(item_id, item_def, use_action)`:
- Read `use_action["amount"]` (default 5).
- Read current player health and max_health.
- Calculate new health (capped at max_health).
- If `item_def["consumable"]`, remove item from inventory.
- Return success with `use_action["text"]` or default message including actual heal amount.

**Step 4 — Handle `sets_flag_on_defeat` in `CombatHandler`**

In `app/lib/classic_game/handlers/combat_handler.rb`, in `handle_creature_defeat`, after removing the creature from the room and clearing combat state, add:

```ruby
# Set defeat flag if specified
game.set_flag(creature_def["sets_flag_on_defeat"], true) if creature_def["sets_flag_on_defeat"]
```

This is needed so the cave's hidden exit can be revealed after the spider is killed.

**Step 5 — Wire up `TestSupport::QaWorldData` in existing files**

- **`test/support/system_test_helper.rb`**: Add `require_relative "qa_world_data"` at top. Change `create_qa_world` body to use `TestSupport::QaWorldData.data` for `world.world_data`.
- **`test/fixtures/worlds.yml`**: Add ERB require at top: `<% require_relative "../support/qa_world_data" %>`. Replace inline JSON in `qa_test_world` with `<%= TestSupport::QaWorldData.data.to_json %>`.
- **`test/fixtures/games.yml`**: Add ERB require at top: `<% require_relative "../support/qa_world_data" %>`. Update `classic_open` fixture's `game_state` to snapshot the new world data: `<%= { "world_snapshot" => TestSupport::QaWorldData.data, "player_states" => {}, "room_states" => {}, "global_flags" => {}, "container_states" => {} }.to_json %>`.
- **`db/seeds/feature_test_world.rb`**: Add `require_relative "../../test/support/qa_world_data"` at top. Replace inline hash with `TestSupport::QaWorldData.data`.

**Step 6 — Update existing system tests in `test/system/classic_game_test.rb`**

- `"initial room description"`: Change `assert_text "Test Chamber"` to `assert_text "Town Square"`.
- `"send look command"`: Change `assert_text "Test Chamber"` to `assert_text "Town Square"`.
- `"navigation command with no exits"`: Town square now has all 4 exits. Change `"go north"` to `"go northeast"` (no NE exit exists) so the "can't go" assertion still holds.
- `"reset game"`: Change `assert_text "Test Chamber"` to `assert_text "Town Square"`.

**Step 7 — Create system test files**

All system tests inherit from `ApplicationSystemTestCase` (which includes `SystemTestHelper`). Each test visits `dev_game_path` which creates the QA world and a game. Use `find(".terminal-input").send_keys("command", :return)` to issue commands and `assert_text` to verify responses.

Create `test/system/qa_world/` directory and the 6 test files listed in section 1. Detailed test cases are in section 4 below.

### 4. Test plan

#### Navigation (`test/system/qa_world/navigation_test.rb`)

| Test name | Setup | Input | Expected output |
|-----------|-------|-------|-----------------|
| `test "move north from town_square to tower_top when unlocked"` | Visit dev_game_path. Set tower_unlocked flag by talking to crier then innkeeper about tower (or directly via debug). | `go north` | Rejection message "tower gate is locked" initially. After flag set and retry: `assert_text "Tower Top"` |
| `test "move south from town_square to cave"` | Visit dev_game_path | `go south` | `assert_text "The Cave"` |
| `test "move east from town_square to tavern"` | Visit dev_game_path | `go east` | `assert_text "The Tavern"` or `assert_text "Tavern"` |
| `test "move west from town_square to market"` | Visit dev_game_path | `go west` | `assert_text "The Market"` or `assert_text "Market"` |
| `test "locked exit blocks movement"` | Visit dev_game_path (no flags set) | `go north` | `assert_text "locked"` (locked_msg from tower exit) |
| `test "unlock exit via flag and move through"` | Visit dev_game_path. Talk to crier (sets spoke_to_crier). Go east to tavern. Talk to innkeeper about tower (sets tower_unlocked). Go west back to town_square. | `go north` | `assert_text "Tower Top"` |

#### Items (`test/system/qa_world/items_test.rb`)

| Test name | Setup | Input | Expected output |
|-----------|-------|-------|-----------------|
| `test "take rusty_key from town_square"` | Visit dev_game_path | `take key` | `assert_text "Rusty Key"` in response; `inventory` shows "Rusty Key" |
| `test "drop item shows it in room"` | Visit dev_game_path, take key | `drop key` then `look` | `assert_text "Rusty Key"` in room description |
| `test "use health_potion outside combat"` | Visit dev_game_path, take key, go east, open chest, take potion | `use potion` | `assert_text "health"` or `assert_text "revitalized"` |

#### Containers (`test/system/qa_world/containers_test.rb`)

| Test name | Setup | Input | Expected output |
|-----------|-------|-------|-----------------|
| `test "open chest without key is rejected"` | Visit dev_game_path, go east (to tavern) | `open chest` | `assert_text "locked"` or `assert_text "needs a key"` |
| `test "open chest with key shows contents"` | Visit dev_game_path, take key, go east | `open chest` | `assert_text "Health Potion"` |

#### NPC Dialogue (`test/system/qa_world/dialogue_test.rb`)

| Test name | Setup | Input | Expected output |
|-----------|-------|-------|-----------------|
| `test "talk to crier shows greeting"` | Visit dev_game_path | `talk to crier` | `assert_text "Hear ye"` or similar greeting |
| `test "talk to innkeeper about base topic"` | Visit dev_game_path, go east | `talk to innkeeper about rooms` | `assert_text "five main areas"` or topic text |
| `test "flag-gated topic shows locked_text before flag"` | Visit dev_game_path, go east | `talk to innkeeper about tower` | `assert_text "don't share secrets"` or locked_text |
| `test "flag-gated topic succeeds after flag set"` | Visit dev_game_path, talk to crier (sets spoke_to_crier), go east | `talk to innkeeper about tower` | `assert_text "unlocked"` or topic text about tower |
| `test "leads_to topic chain"` | Visit dev_game_path, go east | `talk to innkeeper about rooms` | Response mentions "tower" as a follow-up topic; then `talk to innkeeper about tower` follows the chain |

#### NPC Item Exchange (`test/system/qa_world/exchange_test.rb`)

| Test name | Setup | Input | Expected output |
|-----------|-------|-------|-----------------|
| `test "give gem to merchant receives enchanted_sword"` | Visit dev_game_path, unlock tower, go north, take gem, go south, go west | `give gem to merchant` | `assert_text "Enchanted Sword"` |
| `test "give wrong item to merchant is rejected"` | Visit dev_game_path, take key, go west | `give key to merchant` | `assert_text "doesn't want"` |

#### Combat (`test/system/qa_world/combat_test.rb`)

| Test name | Setup | Input | Expected output |
|-----------|-------|-------|-----------------|
| `test "attack cave_spider shows combat feedback"` | Visit dev_game_path, go south | `attack spider` | `assert_text "combat"` or `assert_text "Cave Spider"` and combat prompt |
| `test "defeat spider drops shield"` | Visit dev_game_path, go south, attack spider repeatedly | Multiple `attack` commands | `assert_text "drops"` and `assert_text "Iron Shield"` after defeat |
| `test "flee exits combat"` | Visit dev_game_path, go south, attack spider | `flee` (may need retries due to 50% chance) | Eventually `assert_text "flee"` and no longer in combat |

### 5. Gotchas and constraints

- **Parser split on "to"**: `talk to innkeeper about rooms` currently parses as `{ verb: :talk, target: "", modifier: "innkeeper about rooms" }` because "to" is the first connector found and everything before it (nothing) becomes target. The `resolve_talk_target` helper must split the modifier on " about " to extract NPC name and topic. "talk to crier" gives target="" modifier="crier" — that case needs no further splitting.

- **Dialogue `sets_flag` on greeting vs. topic**: The crier's greeting sets `spoke_to_crier`. This should be handled in `handle_talk_greeting`, not just topic handling. The `dialogue` hash should support a top-level `sets_flag` key on the greeting.

- **`sets_flag_on_defeat` on creatures**: The engine's `CombatHandler#handle_creature_defeat` does NOT currently read a `sets_flag_on_defeat` key from the creature definition. This must be added (Step 4) or the hidden exit in the cave will never reveal.

- **Consumable items outside combat**: The current `ItemHandler#handle_use` does NOT have a `"heal"` case in the `on_use["type"]` switch. Only `CombatHandler#handle_use_item` handles healing via `combat_effect`. Step 3 adds this. The `health_potion` item needs both `on_use` (for outside combat) and `combat_effect` (for inside combat).

- **ContainerHandler checks inventory, not room items**: Confirmed. `ContainerHandler#handle_open` line 38 uses `item?(unlock_item)` which calls `player_state["inventory"]&.include?(unlock_item)`. So the rusty_key must be in inventory (taken), not just lying in the room.

- **RuboCop rules**: Double-quoted strings throughout (matching existing codebase). MethodLength max 60 lines — the `handle_talk` rewrite and `resolve_talk_target` should each stay well under. Frozen string literal comment at top of every file.

- **FakeGame methods available in unit tests**: `set_flag`, `get_flag`, `exit_unlocked?`, `unlock_exit`, `exit_revealed?`, `reveal_exit`, `container_open?`, `open_container`, `close_container`, `container_contents`, `remove_from_container`. The `player_state_in` helper builds player state hashes. `build_world` and `build_game` are available via `ClassicGameTestHelper`.

- **System test timing**: Capybara's `assert_text` has a default wait of 5 seconds (`Capybara.default_max_wait_time = 5`). Combat flee has a 50% success rate — tests may need to retry the flee command or use a loop with a reasonable cap.

- **Fixture ERB require path**: The worlds.yml fixture needs `<% require_relative "../support/qa_world_data" %>` at the very top for the ERB to evaluate. Same for games.yml.

- **Existing system tests**: `classic_game_test.rb` references "Test Chamber" (old starting room name) in 3 assertions and assumes "go north" fails (old room had no exits). All 3 must be updated to "Town Square" and the no-exits test must use a direction that has no exit in the new world.

- **Hidden exit reveal flow**: The cave's east exit to alcove is hidden and requires `spider_slain` flag. The spider's `sets_flag_on_defeat` sets this flag. After killing the spider, `look` in the cave should show the east exit. MovementHandler's `handle_complex_exit` already handles auto-reveal by flag for hidden exits (line 39-43 of movement_handler.rb).

- **`game.starting_hp`**: The `InteractHandler#handle_attack` reads `game.starting_hp` (line 97). `FakeGame` does not implement this. System tests go through the real Game model which does. For unit tests of the talk/topic feature, this is irrelevant. But if adding unit tests for the new talk feature, FakeGame is sufficient.
