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
