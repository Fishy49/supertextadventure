# frozen_string_literal: true

module ClassicGame
  module FunnyResponses
    include ObjectPrompts

    UNKNOWN_COMMAND = [
      "I don't understand '%s'. Did a cat walk across your keyboard? Type HELP for available commands.",
      "I don't understand '%s'. That's not a spell, a command, or interpretive dance. " \
        "Type HELP for available commands.",
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

    TAKE_WHAT = [
      "Take what? Your hands grasp at empty air.",
      "Take what? Be more specific, adventurer.",
      "Take what? There's a lot of stuff around. Narrow it down.",
      "Take what? You mime picking up something invisible.",
      "Take what? You'll need to say what you want."
    ].freeze

    DROP_WHAT = [
      "Drop what? Your hands are already empty on that front.",
      "Drop what? Specify the item you're tired of carrying.",
      "Drop what? You need to be more specific.",
      "Drop what? You pantomime letting go of nothing.",
      "Drop what? Name the thing you wish to discard."
    ].freeze

    USE_WHAT = [
      "Use what? You wiggle your fingers expectantly.",
      "Use what? Specify the item you'd like to employ.",
      "Use what? The dungeon awaits further instructions.",
      "Use what? You need to tell me what to use.",
      "Use what? Your pockets aren't going to search themselves."
    ].freeze

    EXAMINE_WHAT = [
      "Examine what? You squint at nothing in particular.",
      "Examine what? Your magnifying glass hovers aimlessly.",
      "Examine what? Be specific about what catches your eye.",
      "Examine what? You peer around with scholarly intent but no target.",
      "Examine what? Tell me what deserves your scrutiny."
    ].freeze

    OPEN_WHAT = [
      "Open what? You tug at the air expectantly.",
      "Open what? Specify what you'd like to open.",
      "Open what? Your hands reach for an imaginary handle.",
      "Open what? The dungeon has many things — name one.",
      "Open what? You'll need to be more specific."
    ].freeze

    CLOSE_WHAT = [
      "Close what? You push against nothing.",
      "Close what? Specify what needs shutting.",
      "Close what? Your arms swing shut on empty air.",
      "Close what? Name the thing you want closed.",
      "Close what? The dungeon awaits clarification."
    ].freeze

    TALK_TO_WHOM = [
      "Talk to whom? You mumble into the void.",
      "Talk to whom? Specify who deserves your eloquence.",
      "Talk to whom? The walls aren't great conversationalists.",
      "Talk to whom? You clear your throat at nobody.",
      "Talk to whom? Name your intended audience."
    ].freeze

    ATTACK_WHAT = [
      "Attack what? You swing at the air heroically.",
      "Attack what? Specify your target before you hurt yourself.",
      "Attack what? Your weapon thirsts for a named foe.",
      "Attack what? You shadow-box impressively but accomplish nothing.",
      "Attack what? The dungeon suggests picking a real target."
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
