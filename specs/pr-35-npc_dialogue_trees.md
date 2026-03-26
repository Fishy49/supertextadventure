> PR: https://github.com/Fishy49/supertextadventure/pull/35

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

> Generated 2026-03-26

### 1. Files to create

- `test/lib/classic_game/handlers/interact_handler_test.rb` -- Unit tests for the talk/dialogue features in `InteractHandler`, mirroring the pattern used by `CombatHandlerTest`, `ItemHandlerTest`, and `MovementHandlerTest`.

No new production files are needed. All dialogue logic already lives in `InteractHandler` and only requires modification.

### 2. Files to modify

- **`app/lib/classic_game/handlers/interact_handler.rb`**
  - `handle_talk_greeting`: Change to use `dialogue["greeting"]` instead of `dialogue["default"]` for the greeting response. Fall back to `dialogue["default"]` then to `"#{npc_def['name']} nods at you."`.
  - `handle_talk_topic`: Replace exact topic key lookup (`topics[topic_name]`) with a new keyword-matching method `find_topic_by_keyword`.
  - Add new private method `find_topic_by_keyword(topics, topic_name)` -- iterates all topics, checks if any word in the player's input matches any entry in the topic's `"keywords"` array. Falls back to exact key match for backwards compatibility.
  - Add new private method `topic_accessible?(topic, dialogue)` -- checks `leads_to` locking: if a topic is referenced in another topic's `leads_to` array, it is locked until that parent topic has been accessed (i.e., the parent topic's `leads_to` hint has been shown). Since the spec says "no persistent per-NPC conversation state", accessibility is tracked via global flags. When a topic with `leads_to` is successfully accessed, set a flag `"dialogue_unlocked_{topic_id}"` for each topic in the `leads_to` array.
  - Update `handle_talk_topic` to check `leads_to` locking: if a topic appears in any other topic's `leads_to` array, verify the corresponding `"dialogue_unlocked_{topic_id}"` flag is set. If not, return `locked_text` (or `default` if no `locked_text`).
  - Update `handle_talk_topic` to set `"dialogue_unlocked_{id}"` flags for each id in `leads_to` when a topic with `leads_to` is successfully accessed.
  - Update the `leads_to` hint in the response to format as a comma-separated list of topic names (since `leads_to` is an array), e.g., `"\n\nYou could ask about: mine."`.
  - `handle_talk_greeting`: When dialogue has no `"topics"` key, still return the greeting (already works, but confirm no regression).

- **`test/support/qa_world_data.rb`** -- Add `"keywords"` arrays to the innkeeper's existing topics (`"rooms"` and `"tower"`) so existing system tests continue to pass with keyword-based matching. Add `"greeting"` key to innkeeper and crier dialogue hashes for spec compliance.

### 3. Implementation steps

**Step 1: Write unit tests first** (`test/lib/classic_game/handlers/interact_handler_test.rb`)

Create the test file following the exact pattern of `CombatHandlerTest` / `ItemHandlerTest`:
- `include ClassicGameTestHelper`
- `USER_ID = 1`
- `setup` block builds a world with an NPC ("innkeeper") whose dialogue includes: `greeting`, `default`, and `topics` with `town`, `mine`, `work`, `reward`, and `appraisal` (matching the spec's world data example).
- Private `execute(input)` helper that parses + dispatches to `InteractHandler`.
- Tests for each acceptance criterion (see Test Plan below).

**Step 2: Add `"greeting"` support to `handle_talk_greeting`**

In `app/lib/classic_game/handlers/interact_handler.rb`, method `handle_talk_greeting` (line 56):
- Change `response = dialogue["default"] || "#{npc_def['name']} nods at you."` to `response = dialogue["greeting"] || dialogue["default"] || "#{npc_def['name']} nods at you."`.

**Step 3: Add `find_topic_by_keyword` private method**

Add after `resolve_talk_target` in `InteractHandler`:

```ruby
def find_topic_by_keyword(topics, input)
  input_words = input.downcase.split(/\s+/)

  # Try keyword match
  topics.each do |topic_id, topic_def|
    keywords = topic_def["keywords"] || []
    if input_words.any? { |word| keywords.any? { |kw| kw.downcase == word } }
      return [topic_id, topic_def]
    end
  end

  # Fall back to exact topic key match
  topic_def = topics[input.downcase]
  return [input.downcase, topic_def] if topic_def

  [nil, nil]
end
```

**Step 4: Add `leads_to` locking check**

Add private method `topic_locked_by_leads_to?(topic_id, topics)`:

```ruby
def topic_locked_by_leads_to?(topic_id, topics)
  # Check if this topic_id appears in any other topic's leads_to array
  topics.each_value do |other_topic|
    leads_to = other_topic["leads_to"] || []
    next unless leads_to.include?(topic_id)
    # This topic is gated -- check if the unlock flag exists
    return true unless game.get_flag("dialogue_unlocked_#{topic_id}")
  end
  false
end
```

**Step 5: Update `handle_talk_topic` to use keyword matching and leads_to locking**

Replace the body of `handle_talk_topic` (line 65-91):

```ruby
def handle_talk_topic(npc_def, dialogue, topic_name)
  topics = dialogue["topics"]
  return failure("#{npc_def['name']} doesn't know about that.") unless topics

  topic_id, topic = find_topic_by_keyword(topics, topic_name)
  return handle_no_topic_match(npc_def, dialogue) unless topic

  # Check leads_to locking
  if topic_locked_by_leads_to?(topic_id, topics)
    locked_response = topic["locked_text"] || dialogue["default"] || "I wouldn't know anything about that."
    return success("#{npc_def['name']} says: \"#{locked_response}\"")
  end

  # Check flag requirement
  if topic["requires_flag"] && !game.get_flag(topic["requires_flag"])
    locked_response = topic["locked_text"] || dialogue["default"] || "I wouldn't know anything about that."
    return success("#{npc_def['name']} says: \"#{locked_response}\"")
  end

  # Check item requirement
  if topic["requires_item"] && !item?(topic["requires_item"])
    locked_response = topic["locked_text"] || dialogue["default"] || "I wouldn't know anything about that."
    return success("#{npc_def['name']} says: \"#{locked_response}\"")
  end

  # Set flag if specified
  game.set_flag(topic["sets_flag"], true) if topic["sets_flag"]

  # Unlock subtopics via leads_to
  if topic["leads_to"]
    Array(topic["leads_to"]).each do |subtopic_id|
      game.set_flag("dialogue_unlocked_#{subtopic_id}", true)
    end
  end

  # Build response
  response = "#{npc_def['name']} says: \"#{topic['text']}\""

  # Append leads_to hint
  if topic["leads_to"]
    subtopic_names = Array(topic["leads_to"]).join(", ")
    response += "\n\nYou could ask about: #{subtopic_names}."
  end

  success(response)
end
```

**Step 6: Add `handle_no_topic_match` helper**

```ruby
def handle_no_topic_match(npc_def, dialogue)
  default_text = dialogue["default"] || "I wouldn't know anything about that."
  success("#{npc_def['name']} says: \"#{default_text}\"")
end
```

Note: this returns `success`, not `failure`, because the NPC responding with a default is valid game flow, not an error state. The spec examples show default responses as normal NPC speech.

**Step 7: Update locked-topic responses from `failure` to `success`**

The existing code uses `failure(...)` for locked topics (`requires_flag`, `requires_item`). Change these to `success(...)` because the NPC is speaking (saying `locked_text`), which is a successful interaction even though the content is "locked". This matches the spec examples where gated topics show the NPC responding with their locked_text. The `failure` helper should be reserved for actual errors (NPC not found, no dialogue, etc.).

**Step 8: Update `test/support/qa_world_data.rb`**

Add `"greeting"` and `"keywords"` to existing NPC dialogue so system tests continue passing:
- Crier: add `"greeting" => "Hear ye! The innkeeper at the tavern knows many secrets. The tower is locked by ancient magic!"` (same text as current `"default"`).
- Innkeeper: add `"greeting" => "Welcome to the tavern! What would you like to know?"` (same text as current `"default"`). Add `"keywords" => ["rooms", "areas", "room"]` to the `"rooms"` topic. Add `"keywords" => ["tower"]` to the `"tower"` topic. Add `"keywords" => ["supplies", "chest"]` to the `"supplies"` topic.

**Step 9: Run the full test suite and fix any failures.**

### 4. Test plan

Each test uses `ClassicGameTestHelper` with a world containing room `"tavern"`, NPC `"innkeeper"` with full dialogue tree matching the spec's world data example, and NPC `"guard"` with no dialogue key.

**Test: talk_to_npc_with_no_topic_returns_greeting**
- Setup: world with innkeeper (dialogue has `"greeting" => "Welcome, traveller."`), player in tavern, room has innkeeper.
- Input: `"talk to innkeeper"`
- Expected: `result[:success]` is true, response includes `'Innkeeper says: "Welcome, traveller.'`

**Test: talk_to_npc_about_topic_matches_by_keyword**
- Setup: world with innkeeper, topic `"town"` has `keywords: ["town", "village"]`.
- Input: `"talk to innkeeper about village"`
- Expected: response includes `'Innkeeper says: "The town'`

**Test: talk_to_npc_about_topic_exact_keyword_match**
- Setup: same world.
- Input: `"talk to innkeeper about town"`
- Expected: response includes topic text about the town.

**Test: leads_to_unlocks_subtopic**
- Setup: world with innkeeper, `"town"` topic has `leads_to: ["mine"]`.
- Input: first `"talk to innkeeper about town"`, then `"talk to innkeeper about mine"`.
- Expected: second response includes `"Nobody's been down there"`.

**Test: subtopic_locked_before_parent_accessed**
- Setup: same world, mine is in town's `leads_to`.
- Input: `"talk to innkeeper about mine"` (without talking about town first).
- Expected: response includes the `locked_text` (`"I'm not sure what you mean."`)

**Test: subtopic_locked_returns_default_when_no_locked_text**
- Setup: world where a locked subtopic has no `locked_text` key.
- Input: attempt to access locked subtopic.
- Expected: response includes the `default` dialogue text.

**Test: requires_flag_returns_locked_text_when_flag_not_set**
- Setup: world with innkeeper, `"reward"` topic has `requires_flag: "rats_cleared"`.
- Input: `"talk to innkeeper about reward"`
- Expected: response includes `"Bring me proof the rats are gone first."`

**Test: requires_flag_returns_text_when_flag_set**
- Setup: same world, but `game.set_flag("rats_cleared", true)` before command.
- Input: `"talk to innkeeper about reward"`
- Expected: response includes `"You did it!"`

**Test: requires_item_returns_locked_text_when_item_not_in_inventory**
- Setup: world with innkeeper, `"appraisal"` topic has `requires_item: "sword"`, player has no sword.
- Input: `"talk to innkeeper about appraisal"`
- Expected: response includes `"Bring me something worth appraising."`

**Test: requires_item_returns_text_when_item_in_inventory**
- Setup: same world, player inventory includes `"sword"`.
- Input: `"talk to innkeeper about appraisal"`
- Expected: response includes `"Fine craftsmanship."`

**Test: sets_flag_is_set_when_topic_accessed**
- Setup: world with innkeeper, `"work"` topic has `sets_flag: "rat_quest_started"`.
- Input: `"talk to innkeeper about work"`
- Expected: `game.get_flag("rat_quest_started")` is truthy.

**Test: no_keyword_match_returns_default**
- Setup: world with innkeeper, `default: "I wouldn't know anything about that."`
- Input: `"talk to innkeeper about dragons"`
- Expected: response includes `"I wouldn't know anything about that."`

**Test: npc_with_no_dialogue_shows_not_interested**
- Setup: world with guard NPC with `"name" => "Guard"` and no `"dialogue"` key. Guard is in room.
- Input: `"talk to guard"`
- Expected: response includes `"Guard doesn't seem interested in talking."`

**Test: npc_with_dialogue_but_no_topics_returns_greeting_only**
- Setup: world with NPC that has `"dialogue" => { "greeting" => "Hello." }` but no `"topics"` key.
- Input: `"talk to npc"` -- returns greeting.
- Input: `"talk to npc about anything"` -- returns "doesn't know about that" failure.

**Test: talk_to_npc_not_in_room_fails**
- Setup: world with innkeeper NPC defined but not in current room's NPC list.
- Input: `"talk to innkeeper"`
- Expected: response includes "don't see anyone like that".

**Test: talk_with_no_target_fails**
- Input: `"talk"`
- Expected: response includes "Talk to whom?".

### 5. Gotchas and constraints

- **Parser behaviour**: `"talk to innkeeper about town"` parses as `verb: :talk, target: "", modifier: "innkeeper about town"`. The `resolve_talk_target` method splits the modifier on `" about "` to extract the NPC name and topic. This existing parsing flow must not be changed.

- **`failure` vs `success` for locked topics**: The current code returns `failure(...)` for locked topics. The spec examples show locked-text responses as normal NPC speech (e.g., `Innkeeper says: "Bring me proof..."`). These should be `success(...)` because the NPC did respond -- the player's command was valid. `failure` should be reserved for cases where the action truly cannot proceed (NPC not found, no dialogue, talk to whom?, etc.). However, changing `failure` to `success` for locked topics will change the return value of `result[:success]` in system tests. Verify that no existing system tests assert `result[:success] == false` for locked dialogue responses.

- **`leads_to` is an array**: The spec world data shows `"leads_to" => ["mine"]` as an array. The existing code at line 89 treats it as a single value for the hint display. The new code must handle it as `Array(topic["leads_to"])` consistently.

- **`leads_to` tracking via global flags**: Since the spec explicitly says "persistent per-NPC conversation state" is out of scope, we use global flags (`"dialogue_unlocked_mine"`) to track which subtopics have been unlocked. This means unlocking a subtopic with one NPC would theoretically unlock a same-named subtopic with another NPC. This is acceptable given the spec's constraints.

- **Keyword matching is word-level**: The spec says "any word in the input matching any keyword in a topic counts as a match." This means `"talk to innkeeper about the quiet town"` should match the `"town"` topic because `"quiet"` and `"town"` are both in its keywords. The implementation splits on whitespace and does exact word-to-keyword comparison (case-insensitive).

- **Backwards compatibility with exact topic key matching**: The existing QA world data and system tests use `"talk to innkeeper about rooms"` where `"rooms"` is the exact topic key. The new `find_topic_by_keyword` must fall back to exact key match so existing worlds without `"keywords"` arrays continue to work.

- **RuboCop rules**: Double-quoted strings (`Style/StringLiterals: double_quotes`). `MethodLength` max 60. `IndentationConsistency: indented_internal_methods` (private methods indented one extra level inside the class). `Metrics/BlockLength` excluded for tests.

- **FakeGame methods available in tests**: `set_flag(name, value)`, `get_flag(name)`, `player_state(user_id)`, `update_player_state(user_id, state)`, `room_state(room_id)`, `world_snapshot`. All are implemented in `ClassicGameTestHelper::FakeGame`.

- **`player_state_in` helper**: Does not accept a `flags` parameter for global flags. Global flags must be set via `game.set_flag(...)` after building the game.

- **The `"greeting"` key is new**: Existing NPC data uses `"default"` for the greeting. The fallback chain `dialogue["greeting"] || dialogue["default"]` ensures backwards compatibility. Update the QA world data to include both keys.
