# Classic Text Adventure Engine

A complete text adventure game engine for creating classic dungeon-crawl and exploration games with support for puzzles, hidden passages, locked doors, NPCs, quests, and complex world interactions.

## Architecture

### Core Components

1. **World Model** - Defines world templates (rooms, items, NPCs, creatures)
2. **Game Model** - Stores game state (snapshots world template + player/room states)
3. **CommandParser** - Parses natural language commands into structured actions
4. **Engine** - Orchestrates command execution
5. **Handlers** - Specialized handlers for different command types

### Data Flow

```
Player Input → CommandParser → Engine → Handler → GameState Update → Response
```

## World Definition Format

Worlds are defined in JSONB with the following structure:

```json
{
  "meta": {
    "starting_room": "entrance",
    "version": "1.0"
  },
  "rooms": {
    "room_id": {
      "name": "Room Name",
      "description": "Room description...",
      "exits": {
        "north": "other_room_id",
        "east": {
          "to": "locked_room",
          "requires": "key_id",
          "locked_msg": "The door is locked.",
          "unlocked_msg": "The unlocked door stands open to the east."
        },
        "secret": {
          "to": "hidden_chamber",
          "hidden": true,
          "requires_flag": "bookcase_moved",
          "reveal_msg": "You notice a dark passage!",
          "use_item": "iron_key",
          "on_unlock": "You turn the key and the door unlocks.",
          "permanently_unlock": true,
          "consume_item": false,
          "sets_flag": "secret_door_open"
        }
      },
      "items": ["item_id"],
      "npcs": ["npc_id"],
      "on_enter": {
        "type": "message",
        "text": "Special message on first visit"
      }
    }
  },
  "items": {
    "item_id": {
      "name": "Item Name",
      "description": "Item description...",
      "keywords": ["keyword1", "keyword2"],
      "takeable": true,
      "on_use": {
        "type": "unlock",
        "requires_target": true,
        "sets_flag": "door_unlocked",
        "success_msg": "You unlock the door!"
      },
      "reveals_exit": {
        "direction": "down",
        "message": "You pull the lever and a trapdoor opens!"
      },
      "on_examine": {
        "reveals_exit": "secret",
        "text": "Looking closely, you notice something hidden..."
      }
    }
  },
  "npcs": {
    "npc_id": {
      "name": "NPC Name",
      "description": "NPC description...",
      "keywords": ["keyword1"],
      "dialogue": {
        "default": "Hello traveler!",
        "ask about quest": "I need help finding my lost ring..."
      },
      "accepts_item": "quest_item_id",
      "gives_item": "reward_item_id",
      "accept_message": "Thank you for finding my ring!",
      "sets_flag": "quest_complete"
    }
  }
}
```

## Supported Commands

### Movement
- `GO/MOVE/WALK [direction/keyword]` - Move in a direction or use exit keyword (e.g., "go north" or "go door")
- `N/S/E/W/NE/NW/SE/SW/U/D` - Quick direction shortcuts
- `ENTER`, `LEAVE`, `CLIMB`

### Observation
- `LOOK` - Examine current room
- `EXAMINE/INSPECT [object]` - Examine specific object
- `INVENTORY/I` - Check your inventory

### Items
- `TAKE/GET/GRAB [item]` - Pick up an item
- `DROP [item]` - Drop an item
- `USE [item]` - Use an item (triggers on_use or reveals_exit)
- `USE [item] ON [direction/keyword]` - Use an item on an exit (e.g., "use key on north" or "use key on door")

### Interaction
- `TALK TO [npc]` - Talk to an NPC
- `GIVE [item] TO [npc]` - Give an item to an NPC
- `ATTACK [creature]` - Attack (not yet implemented)

### Special
- `HELP` - Show available commands

## Game State Structure

Stored in `Game#game_state` JSONB column:

```json
{
  "world_snapshot": {
    // Copy of world_data at game creation time
    // Isolates game from future world template changes
  },
  "player_states": {
    "user_123": {
      "current_room": "entrance",
      "inventory": ["torch", "key"],
      "health": 100,
      "visited_rooms": ["entrance", "hall"],
      "flags": { "met_guard": true }
    }
  },
  "room_states": {
    "entrance": {
      "items": ["scroll"],
      "npcs": ["guard"],
      "modified": true
    }
  },
  "global_flags": {
    "gate_opened": false,
    "quest_complete": true
  },
  "unlocked_exits": {
    "entrance_north": true,
    "vault_east": true
  },
  "revealed_exits": {
    "library_secret": true,
    "study_hidden": true
  }
}
```

## Creating a New World

```ruby
World.create!(
  name: "My Adventure",
  description: "An exciting adventure",
  world_data: {
    "meta" => {
      "starting_room" => "start",
      "version" => "1.0"
    },
    "rooms" => {
      "start" => {
        "name" => "Starting Room",
        "description" => "You are in the starting room.",
        "exits" => { "north" => "room2" },
        "items" => [],
        "npcs" => []
      }
    },
    "items" => {},
    "npcs" => {}
  }
)
```

## Creating a Game with Classic Mode

```ruby
game = Game.create!(
  name: "My Classic Game",
  game_type: "classic",
  world_id: world.id,  # Select the world template
  created_by: user.id,
  # ... other fields
)
# World is automatically snapshotted into game_state via after_create callback
# This isolates the game from future changes to the world template
```

## Features

### Advanced Exit System

#### Simple Exits
Basic string format for open passages:
```json
"exits": {
  "north": "room_id"
}
```

#### Locked Exits
Exits can be locked with multiple unlock mechanisms:

**Inventory-Based Locking** - Requires item in inventory:
```json
"north": {
  "to": "vault",
  "requires": "gold_key",
  "locked_msg": "You need a key to unlock this vault door."
}
```

**Flag-Based Locking** - Requires global flag to be set:
```json
"east": {
  "to": "treasure_room",
  "requires_flag": "lever_pulled",
  "locked_msg": "A massive gate blocks the way.",
  "unlocked_msg": "The gate stands open."
}
```

**Interactive Unlocking** - Use specific item on exit:
```json
"north": {
  "to": "cell",
  "keywords": ["door", "iron door", "cell door"],
  "use_item": "iron_key",
  "on_unlock": "You turn the key. The door unlocks with a CLUNK!",
  "permanently_unlock": true,
  "consume_item": false
}
```

#### Exit Keywords for Natural Language

The `keywords` property allows players to reference exits using natural language instead of just compass directions. This makes commands more intuitive and immersive.

**How it works:**
- Add a `keywords` array to any exit (works with both simple and complex exits)
- Players can use these keywords in place of directions in commands
- Keywords are matched case-insensitively and support multi-word phrases
- Keywords work with any command that targets exits: `USE [item] ON [keyword]`, `GO [keyword]`, etc.

**Example:**
```json
"north": {
  "to": "shop",
  "keywords": ["door", "shop door", "wooden door"],
  "use_item": "crowbar",
  "on_unlock": "You pry the boards off with the crowbar!",
  "permanently_unlock": true
}
```

**Player commands that work:**
- `use crowbar on north` (direction)
- `use crowbar on door` (keyword)
- `use crowbar on shop door` (multi-word keyword)
- `use crowbar on wooden door` (alternative keyword)
- `go door` (movement via keyword)

**Benefits:**
- More natural and immersive gameplay ("use key on gate" vs "use key on north")
- Allows descriptive exit names that match the narrative
- Multiple keywords give players flexibility in how they refer to exits
- Makes puzzles more intuitive (players think "the locked door" not "the north exit")

#### Hidden Exits
Secret exits that must be discovered through various methods:

**Pattern 1: Flag-Based Revelation**
Exit reveals when a flag is set (e.g., lever pulled elsewhere):
```json
"secret": {
  "to": "hidden_vault",
  "hidden": true,
  "requires_flag": "bookcase_moved",
  "reveal_msg": "You notice a dark passage!"
}
```

**Pattern 2: Item Use Revelation**
Using an item reveals the exit:
```json
// In items section:
"lever": {
  "name": "wall lever",
  "takeable": false,
  "reveals_exit": {
    "direction": "down",
    "message": "You pull the lever and a trapdoor opens!"
  }
}
```

**Pattern 3: Examine-Based Discovery**
Examining an object reveals the exit:
```json
"painting": {
  "name": "portrait",
  "takeable": false,
  "on_examine": {
    "reveals_exit": "secret",
    "text": "Behind the painting, you notice the wall seems hollow..."
  }
}
```

#### Exit Properties
- `to` - Destination room ID
- `keywords` - **[NEW]** Array of alternative names for the exit (e.g., `["door", "shop door", "wooden door"]`). Allows natural commands like `use crowbar on door` instead of `use crowbar on north`. Works with all exit types (simple, locked, hidden). Keywords are case-insensitive and support multi-word phrases.
- `requires` - Item ID needed in inventory
- `requires_flag` - Global flag that must be true
- `locked_msg` - Message when exit is locked
- `unlocked_msg` - Message when passing through unlocked exit
- `hidden` - Exit won't show in list until revealed
- `reveal_msg` - Message when exit is first revealed
- `use_item` - Item ID that unlocks this exit
- `on_unlock` - Message when unlocking with item
- `permanently_unlock` - Stays unlocked after first use
- `consume_item` - Remove item when used on exit
- `sets_flag` - Set global flag when unlocked/revealed

### Smart Item/NPC Finding
- Fuzzy matching by keywords
- Partial name matching
- Contextual searching (only in current room/inventory)

### Multi-player Support
- Each player has independent state (position, inventory)
- Shared world state (items taken affect all players)
- Global flags for quest progress

### Extensible Design
- Easy to add new command types via handlers
- Item "on_use" actions for puzzles
- NPC quests and rewards
- Room events (on_enter triggers)

## Future Enhancements

- Combat system with creatures (placeholder exists)
- Player stats (strength, intelligence, etc.)
- Magic system
- Complex dialogue trees
- Random encounters
- Procedural generation
- Achievement system
- Timed events and puzzles
- Light/darkness mechanics
- Inventory weight limits
- Item combining/crafting

## Example Session

```
Player: look
System: === Crypt Entrance ===
        You stand at the entrance of an ancient crypt...
        You see: Rusty Torch
        Exits: NORTH, EAST

Player: take torch
System: You take the Rusty Torch.

Player: n
System: === Main Hall ===
        A vast hall stretches before you...
        Present: Spectral Guardian
        Exits: SOUTH, EAST, WEST, NORTH

Player: talk to ghost
System: Spectral Guardian says: "Whooo seeks to plunder the crypt?..."

Player: go west
System: === Crumbling Library ===
        Shelves of moldering books fill this chamber...
        You see: Ancient Tome, Iron Key
        Exits: EAST

Player: take key
System: You take the Iron Key.

Player: i
System: You are carrying:
          - Rusty Torch
          - Iron Key

Player: use key on door
System: You turn the key and hear a loud CLUNK as the door unlocks.

Player: go north
System: === Treasure Chamber ===
        Gold coins glitter in the torchlight...
        Exits: SOUTH

Player: look
System: === Treasure Chamber ===
        Gold coins glitter in the torchlight...
        You see: Ancient Painting
        Exits: SOUTH

Player: examine painting
System: Looking closely at the painting, you notice the wall behind seems hollow...

        Behind the painting, you spot a small hidden door!

Player: look
System: === Treasure Chamber ===
        Gold coins glitter in the torchlight...
        You see: Ancient Painting
        Exits: SOUTH, SECRET

Player: go secret
System: === Hidden Vault ===
        A secret chamber filled with ancient artifacts...
```

## Testing

Create a classic game and try these commands:
- Type `HELP` to see all commands
- Use `LOOK` to see your surroundings
- Explore with `N`, `S`, `E`, `W`
- Interact with items and NPCs

The sample world "The Forgotten Crypt" is created by default and includes:
- 6 interconnected rooms
- Multiple items to collect
- A locked door requiring a key
- An NPC to interact with
- Hidden treasure to discover

Try creating worlds with:
- Hidden exits revealed by examining objects
- Levers and switches that open doors in other rooms
- Keys that permanently unlock doors
- Secret passages behind moveable objects
- Multi-step puzzles requiring flag chaining
