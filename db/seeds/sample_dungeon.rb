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
        "items" => %w[chest coin healing_potion],
        "npcs" => [],
        "creatures" => ["rat"]
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
        "items" => %w[sword shield],
        "npcs" => [],
        "creatures" => ["skeleton"]
      },

      "library" => {
        "name" => "Crumbling Library",
        "description" => "Shelves of moldering books fill this chamber. Most have rotted away, but a few ancient tomes remain. A reading desk sits in the center, covered in dust.",
        "exits" => {
          "east" => "main_hall"
        },
        "items" => %w[book iron_key],
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
        "keywords" => %w[torch light],
        "takeable" => true
      },

      "chest" => {
        "name" => "Wooden Chest",
        "description" => "An old wooden chest. It appears to be unlocked.",
        "keywords" => %w[chest box],
        "takeable" => false,
        "cant_take_msg" => "The chest is too heavy to carry."
      },

      "coin" => {
        "name" => "Silver Coin",
        "description" => "A tarnished silver coin with an unfamiliar face stamped on it.",
        "keywords" => %w[coin silver],
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
        "description" => "An old sword, covered in rust but still serviceable. It adds 5 damage to your attacks.",
        "keywords" => %w[sword weapon blade],
        "takeable" => true,
        "weapon_damage" => 5
      },

      "dagger" => {
        "name" => "Small Dagger",
        "description" => "A small but sharp dagger. It adds 3 damage to your attacks.",
        "keywords" => %w[dagger knife blade],
        "takeable" => true,
        "weapon_damage" => 3
      },

      "healing_potion" => {
        "name" => "Healing Potion",
        "description" => "A small vial containing a glowing red liquid. Drinking it will restore 20 health.",
        "keywords" => %w[potion healing health vial],
        "takeable" => true,
        "consumable" => true,
        "combat_effect" => {
          "type" => "heal",
          "amount" => 20
        }
      },

      "shield" => {
        "name" => "Wooden Shield",
        "description" => "A sturdy wooden shield. It provides 2 defense.",
        "keywords" => %w[shield wood defense],
        "takeable" => true,
        "defense_bonus" => 2
      },

      "book" => {
        "name" => "Ancient Tome",
        "description" => "A leather-bound book with strange symbols on the cover. The pages are yellow with age, but the text is still legible: 'Seek the key where knowledge dwells.'",
        "keywords" => %w[book tome],
        "takeable" => true
      },

      "treasure" => {
        "name" => "Ornate Treasure Chest",
        "description" => "A magnificent chest filled with gold, jewels, and ancient artifacts. You've won!",
        "keywords" => %w[treasure chest gold],
        "takeable" => false,
        "cant_take_msg" => "The treasure is too valuable to carry alone. You'll need to return with help!"
      }
    },

    "npcs" => {
      "ghost" => {
        "name" => "Spectral Guardian",
        "description" => "A translucent figure in tattered robes floats before you. Its hollow eyes seem to pierce your soul.",
        "keywords" => %w[ghost guardian spirit specter],
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

    "creatures" => {
      "rat" => {
        "name" => "Giant Rat",
        "description" => "A mangy rat the size of a small dog. Its beady eyes glare at you menacingly, and its yellow teeth are bared.",
        "keywords" => %w[rat rodent],
        "health" => 15,
        "attack" => 4,
        "defense" => 0,
        "hostile" => true,
        "loot" => [],
        "on_defeat_msg" => "The giant rat squeaks pitifully and collapses in a heap.",
        "on_flee_msg" => "The rat hisses as you retreat."
      },

      "skeleton" => {
        "name" => "Skeleton Warrior",
        "description" => "A reanimated skeleton armed with rusty weapons. Its bones rattle as it moves, and its empty eye sockets seem to follow you.",
        "keywords" => %w[skeleton warrior undead bones],
        "health" => 30,
        "attack" => 8,
        "defense" => 2,
        "hostile" => true,
        "loot" => %w[dagger coin],
        "on_defeat_msg" => "The skeleton collapses into a pile of bones with a final clatter.",
        "on_flee_msg" => "The skeleton's jaw chatters mockingly as you flee."
      },

      "goblin" => {
        "name" => "Goblin Scout",
        "description" => "A small, green-skinned creature with sharp teeth and beady eyes. It clutches a crude dagger and looks ready for a fight.",
        "keywords" => %w[goblin scout],
        "health" => 25,
        "attack" => 6,
        "defense" => 1,
        "hostile" => true,
        "loot" => %w[coin healing_potion],
        "on_defeat_msg" => "The goblin falls to the ground with a final shriek.",
        "on_flee_msg" => "The goblin hurls insults at you as you retreat!"
      }
    }
  }
end

Rails.logger.debug "✅ Sample dungeon 'The Forgotten Crypt' created!"
