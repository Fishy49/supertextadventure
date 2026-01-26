# Classic Text Adventure Engine

A complete text adventure game engine for creating classic dungeon-crawl and exploration games.

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
          "locked_msg": "The door is locked."
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
- `GO/MOVE/WALK [direction]` - Move in a direction
- `N/S/E/W/NE/NW/SE/SW/U/D` - Quick direction shortcuts
- `ENTER`, `LEAVE`, `CLIMB`

### Observation
- `LOOK` - Examine current room
- `EXAMINE/INSPECT [object]` - Examine specific object
- `INVENTORY/I` - Check your inventory

### Items
- `TAKE/GET/GRAB [item]` - Pick up an item
- `DROP [item]` - Drop an item
- `USE [item] ON [target]` - Use an item on something

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

- Combat system with creatures
- Player stats (strength, intelligence, etc.)
- Magic system
- Complex dialogue trees
- Random encounters
- Procedural generation
- Save/load game state
- Achievement system

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
