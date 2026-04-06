# frozen_string_literal: true

module ClassicGame
  module FunnyResponses
    UNKNOWN_COMMAND = [
      "I don't understand '%s'. Did a cat walk across your keyboard? Type HELP for available commands.",
      "I don't understand '%s'. That's not a spell, a command, or interpretive dance. Type HELP for available commands.",
      "I don't understand '%s'. The dungeon frowns upon gibberish. Type HELP for available commands.",
      "I don't understand '%s'. Even the rats look confused. Type HELP for available commands.",
      "I don't understand '%s'. Try something in the HELP menu next time. Type HELP for available commands."
    ].freeze

    CANT_GO = [
      "You can't go that way. There's a wall there, you know.",
      "You can't go that way. You bonk your head for emphasis.",
      "You can't go that way. The dungeon politely declines.",
      "You can't go that way. Try a direction that actually exists.",
      "You can't go that way. That's just solid stone, friend."
    ].freeze

    GO_WHERE = [
      "Go where? You gesture vaguely into the void.",
      "Go where? The compass spins unhelpfully.",
      "Go where? Maybe pick a direction first.",
      "Go where? Even the exits look confused.",
      "Go where? Specify a direction!"
    ].freeze

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

    DONT_SEE_THAT = [
      "You don't see that here. Try looking around first.",
      "You don't see that here. Maybe it's hiding from you.",
      "You don't see that here. Either it's gone or it was never here.",
      "You don't see that here. Your keen eyes find nothing.",
      "You don't see that here. The room keeps its secrets."
    ].freeze

    DONT_HAVE_THAT = [
      "You don't have that. Check your pockets — still nothing.",
      "You don't have that. Your inventory is disappointingly bare on that front.",
      "You don't have that. Have you tried picking it up first?",
      "You don't have that. Perhaps it's somewhere in the dungeon.",
      "You don't have that. Wishing doesn't make it so."
    ].freeze

    CANT_USE_HERE = [
      "You can't use that here. This is not the right place for such things.",
      "You can't use that here. The dungeon raises an eyebrow.",
      "You can't use that here. Perhaps there's a better context for it.",
      "You can't use that here. Nothing happens. How embarrassing.",
      "You can't use that here. The item sighs with disappointment."
    ].freeze

    NOTHING_SPECIAL = [
      "You see nothing special about that. It's remarkably ordinary.",
      "You see nothing special about that. Your scrutiny reveals only mediocrity.",
      "You see nothing special about that. Just a perfectly normal thing.",
      "You see nothing special about that. Your detective instincts find nothing.",
      "You see nothing special about that. Move along."
    ].freeze

    class << self
      def unknown_command(raw)
        format(UNKNOWN_COMMAND.sample, raw)
      end

      def cant_go = CANT_GO.sample
      def go_where = GO_WHERE.sample
      def take_what = TAKE_WHAT.sample
      def drop_what = DROP_WHAT.sample
      def use_what = USE_WHAT.sample
      def examine_what = EXAMINE_WHAT.sample
      def open_what = OPEN_WHAT.sample
      def close_what = CLOSE_WHAT.sample
      def talk_to_whom = TALK_TO_WHOM.sample
      def attack_what = ATTACK_WHAT.sample
      def dont_see_that = DONT_SEE_THAT.sample
      def dont_have_that = DONT_HAVE_THAT.sample
      def cant_use_here = CANT_USE_HERE.sample
      def nothing_special = NOTHING_SPECIAL.sample
    end
  end
end
