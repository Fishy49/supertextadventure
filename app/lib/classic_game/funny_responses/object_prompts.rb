# frozen_string_literal: true

module ClassicGame
  module FunnyResponses
    module ObjectPrompts
      TAKE_WHAT = [
        "Take what? Your ambition is admirable but vague.",
        "Take what? You grab the air. Nothing happens.",
        "Take what? Be specific — the dungeon contains many things.",
        "Take what? Name the item you'd like to pocket.",
        "Take what? Your hands are ready but your words are not."
      ].freeze

      DROP_WHAT = [
        "Drop what? Everything stays firmly in your pockets.",
        "Drop what? Nothing falls to the floor.",
        "Drop what? Specify which item to drop.",
        "Drop what? You mime dropping something. Very convincing.",
        "Drop what? The floor waits patiently for your answer."
      ].freeze

      USE_WHAT = [
        "Use what? Your intent is mysterious but the syntax is not.",
        "Use what? Specify an item.",
        "Use what? You wave your hands around. Nothing happens.",
        "Use what? Even the most versatile adventurer needs a target.",
        "Use what? The item fairies demand specifics."
      ].freeze

      EXAMINE_WHAT = [
        "Examine what? You squint at everything and learn nothing.",
        "Examine what? Your monocle is ready but your words are not.",
        "Examine what? Name the thing you'd like to scrutinize.",
        "Examine what? Be specific — curiosity needs a subject.",
        "Examine what? You peer intently at the air. Still air."
      ].freeze

      OPEN_WHAT = [
        "Open what? You tug at the air. It refuses to open.",
        "Open what? Name the thing you'd like to pry open.",
        "Open what? Your crowbar stands ready, awaiting a target.",
        "Open what? Specify something with a lid, door, or flap.",
        "Open what? The dungeon's containers remain stubbornly closed."
      ].freeze

      CLOSE_WHAT = [
        "Close what? You shut nothing very dramatically.",
        "Close what? Nothing is closed. Yet.",
        "Close what? Name the thing you'd like to seal.",
        "Close what? You slam an invisible door. Satisfying.",
        "Close what? Specify something that can be closed."
      ].freeze

      TALK_TO_WHOM = [
        "Talk to whom? The walls don't respond well to conversation.",
        "Talk to whom? Your monologue needs an audience.",
        "Talk to whom? Specify who you'd like to chat with.",
        "Talk to whom? The dungeon is oddly quiet. Name someone.",
        "Talk to whom? Even NPCs need to be addressed by name."
      ].freeze

      ATTACK_WHAT = [
        "Attack what? You swing at the air heroically.",
        "Attack what? Your battle cry echoes into the void.",
        "Attack what? Specify a target before you strain something.",
        "Attack what? Violence needs direction. Name something.",
        "Attack what? The dungeon awaits your bloodthirsty specifics."
      ].freeze
    end
  end
end
