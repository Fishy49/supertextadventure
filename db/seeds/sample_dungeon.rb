# frozen_string_literal: true

# Sample Dungeon World for Classic Text Adventure Mode

World.find_or_create_by!(name: "The Forgotten Crypt") do |world|
  world.description = "A small dungeon adventure to test your wits"
  world.world_data = {
    "meta" => {
      "starting_room" => "entrance",
      "version" => "1.0",
      "author" => "SuperTextAdventure"
    },

    "rooms" => {
      "entrance" => {
        "name" => "Crypt Entrance",
        "description" => "You stand at the entrance of an ancient crypt. Weathered stone walls stretch upward, covered in moss and age. A rusty iron gate hangs open to the north. To the east, you see a small alcove.",
        "exits" => {
          "north" => "main_hall",
          "east" => "alcove"
        },
        "items" => ["torch"],
        "npcs" => []
      },

      "alcove" => {
        "name" => "Dusty Alcove",
        "description" => "A small alcove carved into the eastern wall. Cobwebs hang thick in the corners, and dust covers every surface. An old wooden chest sits in the corner.",
        "exits" => {
          "west" => "entrance"
        },
        "items" => ["chest", "coin"],
        "npcs" => []
      },

      "main_hall" => {
        "name" => "Main Hall",
        "description" => "A vast hall stretches before you, supported by crumbling pillars. Ancient tapestries, now mere rags, hang from the walls. The air is thick with dust and the smell of decay. A locked iron door blocks the way north. Passages lead east and west.",
        "exits" => {
          "south" => "entrance",
          "east" => "armory",
          "west" => "library",
          "north" => {
            "to" => "treasure_room",
            "requires" => "iron_key",
            "locked_msg" => "The iron door is locked tight. You need a key."
          }
        },
        "items" => [],
        "npcs" => ["ghost"]
      },

      "armory" => {
        "name" => "Abandoned Armory",
        "description" => "Rusted weapons and broken shields line the walls of this old armory. Most equipment has long since decayed beyond use. A single torch bracket remains on the north wall.",
        "exits" => {
          "west" => "main_hall"
        },
        "items" => ["sword"],
        "npcs" => []
      },

      "library" => {
        "name" => "Crumbling Library",
        "description" => "Shelves of moldering books fill this chamber. Most have rotted away, but a few ancient tomes remain. A reading desk sits in the center, covered in dust.",
        "exits" => {
          "east" => "main_hall"
        },
        "items" => ["book", "iron_key"],
        "npcs" => []
      },

      "treasure_room" => {
        "name" => "Treasure Chamber",
        "description" => "You have discovered the treasure room! Gold coins and precious gems are scattered across the floor. At the center sits an ornate chest, miraculously untouched by time.",
        "exits" => {
          "south" => "main_hall"
        },
        "items" => ["treasure"],
        "npcs" => [],
        "on_enter" => {
          "type" => "message",
          "text" => "Congratulations! You've found the legendary treasure of the Forgotten Crypt!"
        }
      }
    },

    "items" => {
      "torch" => {
        "name" => "Rusty Torch",
        "description" => "A torch with a rusty iron handle. It provides some light.",
        "keywords" => ["torch", "light"],
        "takeable" => true
      },

      "chest" => {
        "name" => "Wooden Chest",
        "description" => "An old wooden chest. It appears to be unlocked.",
        "keywords" => ["chest", "box"],
        "takeable" => false,
        "cant_take_msg" => "The chest is too heavy to carry."
      },

      "coin" => {
        "name" => "Silver Coin",
        "description" => "A tarnished silver coin with an unfamiliar face stamped on it.",
        "keywords" => ["coin", "silver"],
        "takeable" => true
      },

      "iron_key" => {
        "name" => "Iron Key",
        "description" => "A heavy iron key, surprisingly free of rust. It looks important.",
        "keywords" => ["key", "iron key"],
        "takeable" => true
      },

      "sword" => {
        "name" => "Rusty Sword",
        "description" => "An old sword, covered in rust but still serviceable.",
        "keywords" => ["sword", "weapon", "blade"],
        "takeable" => true
      },

      "book" => {
        "name" => "Ancient Tome",
        "description" => "A leather-bound book with strange symbols on the cover. The pages are yellow with age, but the text is still legible: 'Seek the key where knowledge dwells.'",
        "keywords" => ["book", "tome"],
        "takeable" => true
      },

      "treasure" => {
        "name" => "Ornate Treasure Chest",
        "description" => "A magnificent chest filled with gold, jewels, and ancient artifacts. You've won!",
        "keywords" => ["treasure", "chest", "gold"],
        "takeable" => false,
        "cant_take_msg" => "The treasure is too valuable to carry alone. You'll need to return with help!"
      }
    },

    "npcs" => {
      "ghost" => {
        "name" => "Spectral Guardian",
        "description" => "A translucent figure in tattered robes floats before you. Its hollow eyes seem to pierce your soul.",
        "keywords" => ["ghost", "guardian", "spirit", "specter"],
        "dialogue" => {
          "default" => "Whooo seeks to plunder the crypt? Turn back, mortal, before it is too late! ...Though if you must proceed, you'll need the iron key.",
          "ask about key" => "The key? It lies where knowledge was once kept..."
        },
        "accepts_item" => "coin",
        "gives_item" => nil,
        "accept_message" => "The ghost examines the coin. 'Ah, a token of the old realm. I will let you pass, but be warned...'",
        "sets_flag" => "ghost_pacified"
      }
    },

    "creatures" => {}
  }
end

puts "✅ Sample dungeon 'The Forgotten Crypt' created!"
