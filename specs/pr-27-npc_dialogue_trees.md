> PR: https://github.com/Fishy49/supertextadventure/pull/27

# NPC Dialogue Trees

Players can have free-text conversations with NPCs that branch based on
topic, and optionally on world state (flags/inventory).

---

## Player-facing behaviour

### Talk with no topic — shows greeting
```
> talk to innkeeper
Innkeeper says: "Welcome, traveller. What brings you to these parts?"
```

### Talk about a specific topic
```
> talk to innkeeper about town
Innkeeper says: "The town's been quiet since the mine closed. Folk are scared."
```

### Topic leads to a subtopic
```
> talk to innkeeper about town
Innkeeper says: "The town's been quiet since the mine closed. Folk are scared."

> talk to innkeeper about mine
Innkeeper says: "Nobody's been down there since the collapse."
```

`mine` is only reachable because `town` has `leads_to: ["mine"]`. Asking
about `mine` before `town` returns the default response.

### Topic gated on a flag
```
# rats_cleared flag not set
> talk to innkeeper about reward
Innkeeper says: "Bring me proof the rats are gone first."

# rats_cleared flag is set
> talk to innkeeper about reward
Innkeeper says: "You did it! Here's what I promised."
```

### Topic gated on inventory
```
# sword not in inventory
> talk to blacksmith about appraisal
Blacksmith says: "Bring me something worth appraising."

# sword in inventory
> talk to blacksmith about appraisal
Blacksmith says: "Fine craftsmanship. That blade is worth 50 gold."
```

### No match — default response
```
> talk to innkeeper about dragons
Innkeeper says: "I wouldn't know anything about that."
```

### NPC has no dialogue
```
> talk to guard
Guard doesn't seem interested in talking.
```

---

## World data format

```ruby
"innkeeper" => {
  "name" => "Innkeeper",
  "keywords" => ["innkeeper"],
  "dialogue" => {
    "greeting" => "Welcome, traveller. What brings you to these parts?",
    "default"  => "I wouldn't know anything about that.",
    "topics" => {
      "town" => {
        "keywords"  => ["town", "village", "quiet"],
        "text"      => "The town's been quiet since the mine closed. Folk are scared.",
        "leads_to"  => ["mine"]
      },
      "mine" => {
        "keywords"  => ["mine", "collapse", "closed"],
        "text"      => "Nobody's been down there since the collapse.",
        "locked_text" => "I'm not sure what you mean."
      },
      "work" => {
        "keywords"    => ["work", "job", "help"],
        "text"        => "I need someone to clear the rats from my cellar.",
        "sets_flag"   => "rat_quest_started"
      },
      "reward" => {
        "keywords"      => ["reward", "payment", "done"],
        "requires_flag" => "rats_cleared",
        "text"          => "You did it! Here's what I promised.",
        "locked_text"   => "Bring me proof the rats are gone first."
      },
      "appraisal" => {
        "keywords"      => ["appraise", "appraisal", "worth"],
        "requires_item" => "sword",
        "text"          => "Fine craftsmanship. That blade is worth 50 gold.",
        "locked_text"   => "Bring me something worth appraising."
      }
    }
  }
}
```

---

## Acceptance criteria

- `talk to [npc]` with no topic returns the `greeting`
- `talk to [npc] about [topic]` matches by keyword (any word in the input
  matching any keyword in a topic counts as a match)
- A topic with `leads_to` unlocks those subtopics; attempting to access a
  subtopic before its parent returns `locked_text` (or `default` if none)
- A topic with `requires_flag` returns `locked_text` if the flag is not set,
  and `text` if it is
- A topic with `requires_item` returns `locked_text` if the item is not in
  inventory, and `text` if it is
- A topic with `sets_flag` sets that flag when successfully accessed
- No keyword match returns `default`
- NPC with no `dialogue` key: "[Name] doesn't seem interested in talking."
- NPC with `dialogue` but no `topics`: returns greeting only

## Out of scope
- Persistent per-NPC conversation state (tracking which topics have been seen)
- NPC-initiated dialogue
- Dialogue affecting combat
- Items given through dialogue (use the existing `give` command instead)

---

## Implementation plan

> Generated 2026-03-23

### 1. Files to create

| File | Purpose |
|------|---------|
| `test/lib/classic_game/handlers/interact_handler_test.rb` | Minitest suite covering all dialogue-tree acceptance criteria via FakeGame |

No new production files are needed; all logic lives inside the existing `InteractHandler`.

---

### 2. Files to modify

**`app/lib/classic_game/handlers/interact_handler.rb`**

Replace the stub `handle_talk` private method (lines 21-38) with a full
implementation. Specific methods to add/change inside the `private` section:

- `handle_talk(target, modifier)` — rewrite signature + body; replaces the
  existing stub. Parses `modifier` to extract NPC name and optional topic,
  then delegates to `handle_greeting` or `handle_topic`.
- `handle_greeting(npc_def)` — new method; returns `dialogue["greeting"]`
  wrapped in the standard NPC-says format.
- `handle_topic(npc_id, npc_def, topic_input)` — new method; matches
  `topic_input` words against every topic's `keywords`, applies gate checks,
  sets flags, records `leads_to` unlocks, and returns the appropriate text.
- `topic_unlocked?(npc_id, topic_id, topic_def)` — new method; returns `true`
  when the topic has no parent that gates it (i.e. it is not referenced by any
  other topic's `leads_to`), OR when the player's `dialogue_unlocked` state
  already contains it.
- `record_leads_to_unlocks(npc_id, topic_def)` — new method; appends
  `topic_def["leads_to"]` entries to `player_state["dialogue_unlocked"][npc_id]`
  and calls `update_player_state`.
- `npc_says(npc_def, text)` — new helper; returns
  `success("#{npc_def['name']} says: \"#{text}\"")` to avoid repetition.

Also update the public `handle` method's `:talk` branch to pass both
`command[:target]` and `command[:modifier]` to `handle_talk`.

**`test/support/classic_game_helper.rb`**
No changes needed — `FakeGame#set_flag`, `FakeGame#get_flag`, and
`build_game`/`player_state_in`/`build_world` are already sufficient.

---

### 3. Implementation steps

#### Step 1 — Fix the `handle` dispatch for `:talk`

In `ClassicGame::Handlers::InteractHandler#handle`, change:

```ruby
when :talk
  handle_talk(command[:target])
```

to:

```ruby
when :talk
  handle_talk(command[:target], command[:modifier])
```

**Why:** The CommandParser puts the NPC name in `command[:modifier]` (not
`target`) for `talk to X` because it splits on the word `"to"`. For
`"talk to innkeeper"`, `target = ""` and `modifier = "innkeeper"`. For
`"talk to innkeeper about town"`, `modifier = "innkeeper about town"`.

#### Step 2 — Rewrite `handle_talk`

Replace the existing `handle_talk(target)` body with:

```ruby
def handle_talk(target, modifier)
  # Modifier holds "npc_name" or "npc_name about topic_words"
  raw = modifier.presence || target.presence
  return failure("Talk to whom?") unless raw

  # Split on " about " to separate npc from topic
  parts = raw.split(/\s+about\s+/, 2)
  npc_input  = parts[0].strip
  topic_input = parts[1]&.strip

  npc_id, npc_def = find_npc(npc_input)
  return failure("You don't see anyone like that here.") unless npc_def
  return failure("You don't see anyone like that here.") unless npc_in_room?(npc_id)

  dialogue = npc_def["dialogue"]
  return failure("#{npc_def['name']} doesn't seem interested in talking.") unless dialogue

  return handle_greeting(npc_def) unless topic_input

  handle_topic(npc_id, npc_def, topic_input)
end
```

#### Step 3 — Add `handle_greeting`

```ruby
def handle_greeting(npc_def)
  greeting = npc_def.dig("dialogue", "greeting") ||
             npc_def.dig("dialogue", "default") ||
             "#{npc_def['name']} nods at you."
  npc_says(npc_def, greeting)
end
```

#### Step 4 — Add `handle_topic`

```ruby
def handle_topic(npc_id, npc_def, topic_input)
  dialogue = npc_def["dialogue"]
  topics   = dialogue["topics"] || {}
  words    = topic_input.downcase.split

  # Find matching topic by keyword intersection
  matched_id, matched_def = topics.find do |_tid, tdef|
    keywords = (tdef["keywords"] || []).map(&:downcase)
    words.any? { |w| keywords.include?(w) }
  end

  # No keyword match
  unless matched_def
    default_text = dialogue["default"] || "#{npc_def['name']} shrugs."
    return npc_says(npc_def, default_text)
  end

  # Gate: topic only reachable via leads_to and not yet unlocked
  unless topic_unlocked?(npc_id, matched_id, matched_def, topics)
    locked = matched_def["locked_text"] || dialogue["default"] || "#{npc_def['name']} shrugs."
    return npc_says(npc_def, locked)
  end

  # Gate: requires_flag
  if (req_flag = matched_def["requires_flag"])
    unless game.get_flag(req_flag)
      locked = matched_def["locked_text"] || dialogue["default"] || "#{npc_def['name']} shrugs."
      return npc_says(npc_def, locked)
    end
  end

  # Gate: requires_item
  if (req_item = matched_def["requires_item"])
    unless item?(req_item)
      locked = matched_def["locked_text"] || dialogue["default"] || "#{npc_def['name']} shrugs."
      return npc_says(npc_def, locked)
    end
  end

  # Success path: set flag if specified
  game.set_flag(matched_def["sets_flag"], true) if matched_def["sets_flag"]

  # Unlock any leads_to subtopics
  record_leads_to_unlocks(npc_id, matched_def)

  npc_says(npc_def, matched_def["text"])
end
```

#### Step 5 — Add `topic_unlocked?`

A topic is gated (requires unlocking via `leads_to`) if and only if some other
topic lists it in its own `leads_to` array. If no topic references it, it is
freely accessible.

```ruby
def topic_unlocked?(npc_id, topic_id, _topic_def, all_topics)
  # Is this topic listed as a child in any other topic's leads_to?
  gated = all_topics.any? do |_tid, tdef|
    (tdef["leads_to"] || []).include?(topic_id)
  end
  return true unless gated

  # Check player's session-level unlocks
  unlocked = player_state.dig("dialogue_unlocked", npc_id) || []
  unlocked.include?(topic_id)
end
```

#### Step 6 — Add `record_leads_to_unlocks`

```ruby
def record_leads_to_unlocks(npc_id, topic_def)
  leads_to = topic_def["leads_to"]
  return unless leads_to&.any?

  new_state = player_state.dup
  new_state["dialogue_unlocked"] ||= {}
  new_state["dialogue_unlocked"][npc_id] ||= []
  new_state["dialogue_unlocked"][npc_id] = (
    new_state["dialogue_unlocked"][npc_id] + leads_to
  ).uniq
  update_player_state(new_state)
end
```

#### Step 7 — Add `npc_says` helper

```ruby
def npc_says(npc_def, text)
  success("#{npc_def['name']} says: \"#{text}\"")
end
```

#### Step 8 — Create the test file

Create `test/lib/classic_game/handlers/interact_handler_test.rb` with all test
cases described in the test plan below (section 4). Mirror the structure of
`combat_handler_test.rb`: `include ClassicGameTestHelper`, define `USER_ID = 1`,
a `setup` block building a world with the innkeeper NPC from the spec, a private
`execute(input)` helper, and tests grouped by feature with banner comments.

---

### 4. Test plan

Shared setup world for all tests (define in `setup`):

```ruby
INNKEEPER_NPC = {
  "name"     => "Innkeeper",
  "keywords" => ["innkeeper"],
  "dialogue" => {
    "greeting" => "Welcome, traveller. What brings you to these parts?",
    "default"  => "I wouldn't know anything about that.",
    "topics"   => {
      "town" => {
        "keywords" => ["town", "village", "quiet"],
        "text"     => "The town's been quiet since the mine closed. Folk are scared.",
        "leads_to" => ["mine"]
      },
      "mine" => {
        "keywords"    => ["mine", "collapse", "closed"],
        "text"        => "Nobody's been down there since the collapse.",
        "locked_text" => "I'm not sure what you mean."
      },
      "work" => {
        "keywords"  => ["work", "job", "help"],
        "text"      => "I need someone to clear the rats from my cellar.",
        "sets_flag" => "rat_quest_started"
      },
      "reward" => {
        "keywords"      => ["reward", "payment", "done"],
        "requires_flag" => "rats_cleared",
        "text"          => "You did it! Here's what I promised.",
        "locked_text"   => "Bring me proof the rats are gone first."
      },
      "appraisal" => {
        "keywords"      => ["appraise", "appraisal", "worth"],
        "requires_item" => "sword",
        "text"          => "Fine craftsmanship. That blade is worth 50 gold.",
        "locked_text"   => "Bring me something worth appraising."
      }
    }
  }
}.freeze

SILENT_GUARD = {
  "name"     => "Guard",
  "keywords" => ["guard"]
  # no "dialogue" key
}.freeze
```

World: one room `"tavern"` with `npcs: ["innkeeper", "guard"]`.

---

**Test: greeting with no topic**
- **Test name:** `"talk to npc with no topic returns greeting"`
- **Setup:** default world, player in "tavern", no flags/inventory
- **Input:** `"talk to innkeeper"`
- **Expected:** `result[:success]` is true; `result[:response]` includes `"Welcome, traveller"`

**Test: greeting with no topic — response format**
- **Test name:** `"talk response wraps text in npc-says format"`
- **Input:** `"talk to innkeeper"`
- **Expected:** `result[:response]` matches `'Innkeeper says: "'`

**Test: topic matched by keyword**
- **Test name:** `"talk about topic matches by keyword"`
- **Input:** `"talk to innkeeper about town"`
- **Expected:** `result[:success]` true; response includes `"mine closed"`

**Test: topic matched by alternate keyword**
- **Test name:** `"talk about topic matches alternate keyword in topic"`
- **Input:** `"talk to innkeeper about village"`
- **Expected:** response includes `"mine closed"` (same town topic matched by `"village"`)

**Test: leads_to — blocked before parent**
- **Test name:** `"subtopic locked before parent topic accessed"`
- **Setup:** no prior dialogue; player has not talked about town
- **Input:** `"talk to innkeeper about mine"`
- **Expected:** `result[:success]` true; response includes `"I'm not sure what you mean"`

**Test: leads_to — unlocked after parent**
- **Test name:** `"subtopic accessible after parent topic accessed"`
- **Setup:** execute `"talk to innkeeper about town"` first (which records leads_to), then:
- **Input:** `"talk to innkeeper about mine"`
- **Expected:** response includes `"Nobody's been down there"`

**Test: leads_to records unlock in player state**
- **Test name:** `"accessing parent topic records subtopic in player dialogue_unlocked"`
- **Input:** `"talk to innkeeper about town"`
- **Expected:** `game.player_state(USER_ID).dig("dialogue_unlocked", "innkeeper")` includes `"mine"`

**Test: requires_flag — locked**
- **Test name:** `"topic with requires_flag returns locked_text when flag not set"`
- **Setup:** no flags set
- **Input:** `"talk to innkeeper about reward"`
- **Expected:** response includes `"Bring me proof"`

**Test: requires_flag — unlocked**
- **Test name:** `"topic with requires_flag returns text when flag is set"`
- **Setup:** `game.set_flag("rats_cleared", true)` before executing
- **Input:** `"talk to innkeeper about reward"`
- **Expected:** response includes `"You did it"`

**Test: requires_item — locked**
- **Test name:** `"topic with requires_item returns locked_text when item not in inventory"`
- **Setup:** player inventory = `[]`
- **Input:** `"talk to innkeeper about appraisal"`
- **Expected:** response includes `"Bring me something worth appraising"`

**Test: requires_item — unlocked**
- **Test name:** `"topic with requires_item returns text when item in inventory"`
- **Setup:** player inventory = `["sword"]`; sword defined in world items
- **Input:** `"talk to innkeeper about appraisal"`
- **Expected:** response includes `"Fine craftsmanship"`

**Test: sets_flag**
- **Test name:** `"accessing topic with sets_flag sets the flag"`
- **Input:** `"talk to innkeeper about work"`
- **Expected:** `game.get_flag("rat_quest_started")` is truthy after call

**Test: no keyword match returns default**
- **Test name:** `"talk about unrecognized topic returns default response"`
- **Input:** `"talk to innkeeper about dragons"`
- **Expected:** `result[:success]` true; response includes `"I wouldn't know anything about that"`

**Test: NPC has no dialogue**
- **Test name:** `"talk to npc with no dialogue returns not interested message"`
- **Input:** `"talk to guard"`
- **Expected:** `result[:success]` false; response includes `"Guard doesn't seem interested in talking"`

**Test: NPC has dialogue but no topics — greeting only**
- **Test name:** `"talk to npc with dialogue but no topics returns greeting"`
- **Setup:** add NPC `"shopkeeper"` to world with `dialogue: { "greeting" => "Hello there." }` and no `topics` key; place in room
- **Input:** `"talk to shopkeeper"`
- **Expected:** response includes `"Hello there."`

**Test: NPC not in room**
- **Test name:** `"talk to npc not in current room fails"`
- **Setup:** innkeeper not in `current_room_state["npcs"]`
- **Input:** `"talk to innkeeper"`
- **Expected:** `result[:success]` false; response includes `"don't see anyone"`

**Test: no target**
- **Test name:** `"talk with no target fails"`
- **Input:** `"talk"`
- **Expected:** `result[:success]` false; response includes `"whom"`

---

### 5. Gotchas and constraints

**CommandParser target/modifier split for `talk`:**
`"talk to innkeeper"` → `target: ""`, `modifier: "innkeeper"`.
`"talk to innkeeper about town"` → `target: ""`, `modifier: "innkeeper about town"`.
`"talk innkeeper"` (no "to") → `target: "innkeeper"`, `modifier: nil`.
The handler must merge `modifier.presence || target.presence` before splitting on `" about "`.

**`leads_to` gating is session-scoped, not global:**
The spec says persistent per-NPC conversation state is out of scope, but the
`leads_to` requirement IS in scope. Store unlocks in
`player_state["dialogue_unlocked"][npc_id]` (a plain array of topic IDs). This
is per-user, per-game-session, and is reset when the game restarts (because
`game_state["player_states"]` is cleared on restart in `engine.rb`).

**`sets_flag` uses `game.set_flag`, not player_state flags:**
All flag operations in the codebase (`item_handler.rb`, `interact_handler.rb`
give handler, `movement_handler.rb`) use `game.set_flag` / `game.get_flag`,
which writes to `game_state["global_flags"]`. Do NOT write into
`player_state["flags"]` — the `requires_flag` gate must use `game.get_flag`.

**RuboCop MethodLength (max 60 lines):**
`handle_topic` is the longest method; keep each branch terse. Extract the
three lock-check branches into a single `locked_response_for(npc_def, topic_def, dialogue)` helper if needed to stay under 60 lines.

**Double-quoted strings:**
All string literals in production Ruby files in this repo use double quotes
(RuboCop enforces `Style/StringLiterals: double_quotes`). Do not use single-quoted
strings in the handler file.

**`success` / `failure` return shape:**
`success(message)` returns `{ success: true, response: message, state_changes: {} }`.
`failure(message)` returns `{ success: false, response: message, state_changes: {} }`.
The dialogue handler returns `success` for all dialogue outputs (including
locked/default), per the spec examples — only "NPC has no dialogue" and guard
clauses (NPC not found, no target) return `failure`.

**`find_npc` is fuzzy but not room-scoped:**
`find_npc` searches the entire world `npcs` hash. The separate `npc_in_room?`
check is required to confirm presence. Always check both (as the existing stub
already does).

**Topic keyword matching — case:**
`topic_input` arrives already downcased (CommandParser normalizes to lowercase).
Topic keywords in world data may be any case; downcase them before comparing.

**`player_state.dup` is shallow:**
When mutating nested hashes (e.g. `dialogue_unlocked`), do a deep enough dup:
`new_state["dialogue_unlocked"] = player_state["dialogue_unlocked"].dup || {}` before
modifying, to avoid mutating the cached `@player_state` in-place.

**`topic_unlocked?` signature change:**
The `all_topics` parameter is needed to check whether any topic references
`topic_id` in its `leads_to`. Pass `topics` (local variable in `handle_topic`)
as the fourth argument; do not call `npc_def.dig(...)` again inside the method.
