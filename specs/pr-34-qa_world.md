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
