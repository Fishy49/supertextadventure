# frozen_string_literal: true

module TestSupport
  module QaWorldData # rubocop:disable Metrics/ModuleLength
    RUSTY_KEY_ART = <<~ART
      ╔═══╗
      ║ ◉ ╠══╗
      ╚═══╝  ║
         ▓▓▓▓╝
    ART

    GEM_ART = <<~ART
      ╔══╦══╗
      ║◆◆║◆◆║
      ╠══╬══╣
      ║◊◊║◊◊║
      ╚══╩══╝
    ART

    SWORD_ART = <<~ART
        ╔╗
        ║║
        ║║
      ╔═╬╬═╗
      ╚═╬╬═╝
        ║║
        ╚╝
    ART

    SHIELD_ART = <<~ART
      ██████████
      █▓▓▓▓▓▓▓█
      █▓▒▒▒▒▓█
      █▓▒░░▒▓█
      ██████████
       ████████
        ██████
         ████
          ██
    ART

    POTION_ART = <<~ART
        _____
       /° ° °\
      | °   ° |
      | ° ° ° |
       _____/
         | |
        =====
    ART

    LOCKPICK_ART = <<~ART
      ⌐──────────┐
                  │
      ⌐──────────┘
    ART

    def self.rusty_key_lore
      "A tarnished rusty iron key, worn smooth by many hands — what lock does it open?"
    end

    def self.gem_lore
      "A faceted jewel that catches even the faintest light, cold and brilliant to the touch."
    end

    def self.sword_lore
      "An enchanted blade humming with arcane energy, its edge never dulling."
    end

    def self.shield_lore
      "A sturdy shield bearing the crest of a forgotten order, still solid as the day it was forged."
    end

    def self.potion_lore
      "A stoppered vial of crimson liquid that seems to pulse with warmth."
    end

    def self.lockpick_lore
      "A slender steel pick, its tip bent just so — in the right hands, no lock is a match for it."
    end

    def self.data
      @data ||= {
        "meta" => meta,
        "rooms" => rooms,
        "items" => items,
        "npcs" => npcs,
        "creatures" => creatures
      }.freeze
    end

    def self.meta
      {
        "starting_room" => "town_square",
        "version" => "2.0",
        "author" => "SuperTextAdventure",
        "description" => "A QA world that has lots of things to test"
      }
    end

    def self.rooms
      {
        "town_square" => town_square_room,
        "tavern" => tavern_room,
        "market" => market_room,
        "cave" => cave_room,
        "tower_top" => tower_top_room,
        "alcove" => alcove_room
      }
    end

    def self.town_square_room
      {
        "name" => "Town Square",
        "description" => "A bustling town square with cobblestone streets. A fountain gurgles in the center.",
        "exits" => {
          "north" => {
            "to" => "tower_top",
            "requires_flag" => "tower_unlocked",
            "locked_msg" => "The tower gate is locked."
          },
          "south" => "cave",
          "east" => "tavern",
          "west" => "market"
        },
        "items" => ["rusty_key"],
        "npcs" => %w[crier patrol_guard]
      }
    end

    def self.tavern_room
      {
        "name" => "The Tavern",
        "description" => "A cozy inn with a roaring fireplace. The smell of ale fills the air.",
        "exits" => { "west" => "town_square" },
        "items" => %w[chest lockpick],
        "npcs" => ["innkeeper"],
        "creatures" => ["tavern_rat"]
      }
    end

    def self.market_room
      {
        "name" => "The Market",
        "description" => "Colorful stalls line the street, filled with exotic wares.",
        "exits" => { "east" => "town_square" },
        "items" => [],
        "npcs" => ["merchant"]
      }
    end

    def self.cave_room
      {
        "name" => "The Cave",
        "description" => "A dark and damp cave. Water drips from the ceiling.",
        "exits" => {
          "north" => "town_square",
          "east" => {
            "to" => "alcove",
            "hidden" => true,
            "requires_flag" => "spider_slain",
            "reveal_msg" => "With the spider defeated, you notice a narrow passage to the east."
          }
        },
        "items" => [],
        "npcs" => [],
        "creatures" => ["cave_spider"]
      }
    end

    def self.tower_top_room
      {
        "name" => "Tower Top",
        "description" => "A high vantage point overlooking the entire town. The wind howls around you.",
        "exits" => { "south" => "town_square" },
        "items" => ["gem"],
        "npcs" => []
      }
    end

    def self.alcove_room
      {
        "name" => "Secret Alcove",
        "description" => "A small hidden chamber carved into the rock. Glittering crystals line the walls.",
        "exits" => { "west" => "cave" },
        "items" => [],
        "npcs" => []
      }
    end

    def self.items
      {
        "rusty_key" => {
          "name" => "Rusty Key",
          "keywords" => %w[key rusty],
          "takeable" => true,
          "description" => "An old rusty iron key.",
          "ascii_art" => RUSTY_KEY_ART,
          "detailed_description" => rusty_key_lore
        },
        "chest" => chest_item,
        "health_potion" => health_potion_item,
        "gem" => {
          "name" => "Sparkling Gem",
          "keywords" => %w[gem sparkling],
          "takeable" => true,
          "description" => "A brilliant gemstone that glows faintly.",
          "ascii_art" => GEM_ART,
          "detailed_description" => gem_lore
        },
        "enchanted_sword" => {
          "name" => "Enchanted Sword",
          "keywords" => %w[sword enchanted],
          "takeable" => true,
          "weapon_damage" => 8,
          "description" => "A sword that hums with magical energy.",
          "ascii_art" => SWORD_ART,
          "detailed_description" => sword_lore
        },
        "shield" => {
          "name" => "Iron Shield",
          "keywords" => %w[shield iron],
          "takeable" => true,
          "defense_bonus" => 3,
          "description" => "A sturdy iron shield.",
          "ascii_art" => SHIELD_ART,
          "detailed_description" => shield_lore
        },
        "lockpick" => lockpick_item
      }
    end

    def self.lockpick_item
      {
        "name" => "Lockpick",
        "keywords" => %w[lockpick pick],
        "takeable" => true,
        "description" => "A thin metal pick for opening locks.",
        "ascii_art" => LOCKPICK_ART,
        "detailed_description" => lockpick_lore,
        "dice_roll" => {
          "dc" => 12,
          "stat" => "dexterity",
          "dice" => "1d20",
          "consume_on" => "failure",
          "completed_message" => "The chest lock is already open.",
          "attempt_message" => "You carefully insert the lockpick and attempt to pick the lock...",
          "on_success" => {
            "sets_flag" => "tavern_lockpick_success",
            "message" => "The lock clicks open with a satisfying snap!"
          },
          "on_failure" => {
            "sets_flag" => "tavern_lockpick_failed",
            "message" => "The lockpick snaps! You will need another approach."
          }
        }
      }
    end

    def self.chest_item
      {
        "name" => "Wooden Chest",
        "keywords" => ["chest"],
        "is_container" => true,
        "starts_closed" => true,
        "locked" => true,
        "unlock_item" => "rusty_key",
        "unlock_flag" => "tavern_lockpick_success",
        "locked_message" => "The chest is locked. You could try picking the lock.",
        "contents" => ["health_potion"],
        "on_open_message" => "You unlock the chest and open it."
      }
    end

    def self.health_potion_item
      {
        "name" => "Health Potion",
        "keywords" => %w[potion health],
        "takeable" => true,
        "consumable" => true,
        "description" => "A bubbling red potion.",
        "ascii_art" => POTION_ART,
        "detailed_description" => potion_lore,
        "on_use" => { "type" => "heal", "amount" => 5, "text" => "You drink the health potion and feel revitalized!" },
        "combat_effect" => { "type" => "heal", "amount" => 5 }
      }
    end

    def self.npcs
      {
        "crier" => {
          "name" => "Town Crier",
          "keywords" => ["crier", "town crier"],
          "description" => "A loud man in official garb.",
          "dialogue" => {
            "greeting" => "Hear ye! The innkeeper at the tavern knows many secrets. " \
                          "The tower is locked by ancient magic!",
            "default" => "Hear ye! The innkeeper at the tavern knows many secrets. " \
                         "The tower is locked by ancient magic!",
            "sets_flag" => "spoke_to_crier"
          }
        },
        "innkeeper" => innkeeper_npc,
        "merchant" => merchant_npc,
        "patrol_guard" => patrol_guard_npc
      }
    end

    def self.innkeeper_npc
      {
        "name" => "Innkeeper",
        "keywords" => %w[innkeeper keeper],
        "description" => "A jovial woman behind the bar.",
        "dialogue" => {
          "greeting" => "Welcome to the tavern! What would you like to know?",
          "default" => "Welcome to the tavern! What would you like to know?",
          "topics" => {
            "rooms" => {
              "keywords" => %w[rooms areas room],
              "text" => "There are five main areas in this town. " \
                        "The square, the tavern, the market, the cave, and the tower."
            },
            "tower" => innkeeper_tower_topic,
            "supplies" => {
              "keywords" => %w[supplies chest],
              "text" => "Ah, you have the key! The chest in the corner holds a potion that might help you.",
              "requires_item" => "rusty_key",
              "locked_text" => "The innkeeper glances at the chest. 'That chest needs a special key to open.'"
            },
            "rumors" => {
              "keywords" => %w[rumors rumor gossip],
              "text" => "Folk say there's something lurking in the cellar beneath the tavern.",
              "leads_to" => ["cellar"]
            },
            "cellar" => {
              "keywords" => %w[cellar basement below],
              "text" => "The cellar entrance is behind the bar. Be careful down there.",
              "locked_text" => "The innkeeper shrugs. 'What cellar? I don't know what you mean.'"
            }
          }
        }
      }
    end

    def self.innkeeper_tower_topic
      {
        "keywords" => ["tower"],
        "text" => "The tower can be unlocked with the right knowledge. " \
                  "I've done it for you — the gate should open now.",
        "requires_flag" => "spoke_to_crier",
        "locked_text" => "The innkeeper eyes you suspiciously. " \
                         "'I don't share secrets with strangers. Perhaps the town crier can vouch for you.'",
        "sets_flag" => "tower_unlocked"
      }
    end

    def self.merchant_npc
      {
        "name" => "Merchant",
        "keywords" => %w[merchant trader],
        "description" => "A shrewd-looking trader.",
        "accepts_item" => "gem",
        "gives_item" => "enchanted_sword",
        "accept_message" => "The merchant's eyes light up! 'A gem! Here, take this enchanted sword in return.'",
        "dialogue" => {
          "greeting" => "Looking to trade? I'm after a sparkling gem. Bring me one and I'll make it worth your while.",
          "default" => "Looking to trade? I'm after a sparkling gem. Bring me one and I'll make it worth your while."
        }
      }
    end

    def self.patrol_guard_npc
      {
        "name" => "Town Guard",
        "keywords" => %w[guard town guard],
        "description" => "A guard making rounds through town.",
        "movement" => {
          "type" => "patrol",
          "schedule" => [
            { "room" => "town_square", "duration" => 3 },
            { "room" => "tavern", "duration" => 3 }
          ],
          "depart_msg" => "The Town Guard heads toward the tavern.",
          "arrive_msg" => "The Town Guard arrives from the tavern."
        }
      }
    end

    def self.creatures
      {
        "cave_spider" => {
          "name" => "Cave Spider",
          "keywords" => ["spider", "cave spider"],
          "description" => "A giant spider lurking in the shadows.",
          "health" => 8,
          "attack" => 3,
          "defense" => 1,
          "hostile" => true,
          "talk_text" => "The spider hisses at you menacingly.",
          "aggro_text" => "The Cave Spider lunges at you!",
          "attack_condition" => { "moves" => 3 },
          "loot" => ["shield"],
          "on_defeat_msg" => "The cave spider crumples to the ground!",
          "on_flee_msg" => "The spider hisses as you retreat.",
          "sets_flag_on_defeat" => "spider_slain"
        },
        "tavern_rat" => {
          "name" => "Tavern Rat",
          "keywords" => ["rat", "tavern rat"],
          "description" => "A fat, lazy rat lounging near the fireplace.",
          "health" => 3,
          "attack" => 1,
          "hostile" => false,
          "talk_text" => "The rat squeaks and twitches its whiskers at you."
        }
      }
    end
  end
end
