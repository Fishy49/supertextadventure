# frozen_string_literal: true

module ClassicGame
  class CommandParser
    # Common verb synonyms
    VERBS = {
      # Movement
      go: %w[go move walk travel head],
      enter: %w[enter],
      leave: %w[leave exit],
      climb: %w[climb scale],

      # Observation
      look: %w[look l],
      examine: %w[examine inspect x check read],
      inventory: %w[inventory inv i],

      # Items
      take: %w[take get grab pickup pick],
      drop: %w[drop discard],
      use: %w[use activate employ apply],
      open: %w[open unlock],
      close: %w[close shut],

      # Interaction
      talk: %w[talk speak chat ask say],
      attack: %w[attack kill hit strike fight],
      give: %w[give offer hand],

      # Combat
      defend: %w[defend block guard parry],
      flee: %w[flee run escape retreat],

      # Special
      help: %w[help h ?],
      save: %w[save],
      quit: %w[quit exit q],
      restart: %w[restart reset]
    }.freeze

    # Direction synonyms
    DIRECTIONS = {
      north: %w[north n],
      south: %w[south s],
      east: %w[east e],
      west: %w[west w],
      northeast: %w[northeast ne],
      northwest: %w[northwest nw],
      southeast: %w[southeast se],
      southwest: %w[southwest sw],
      up: %w[up u],
      down: %w[down d],
      in: %w[in],
      out: %w[out]
    }.freeze

    # Prepositions to filter out
    PREPOSITIONS = %w[the a an to at on with from of].freeze

    class << self
      def parse(input)
        return { verb: :unknown, raw: input } if input.blank?

        # Normalize input
        normalized = input.downcase.strip

        # Parse the command
        verb, target, modifier = extract_parts(normalized)

        {
          verb: verb,
          target: target,
          modifier: modifier,
          raw: input
        }
      end

      private

      def extract_parts(text)
        words = text.split(/\s+/)

        # Check for direction-only commands (n, s, e, w, etc.)
        if words.length == 1 && find_direction(words[0])
          return [:go, find_direction(words[0]), nil]
        end

        # Extract verb
        first_word = words.shift
        verb = find_verb(first_word) || :unknown

        # Handle special cases
        case verb
        when :go, :enter, :leave, :climb
          # Remove prepositions for movement
          cleaned_words = words.reject { |w| PREPOSITIONS.include?(w) }
          direction = find_direction(cleaned_words.first)
          return [verb, direction || cleaned_words.join(" "), nil]

        when :look, :examine
          # Remove prepositions for observation
          cleaned_words = words.reject { |w| PREPOSITIONS.include?(w) }
          target = cleaned_words.empty? ? nil : cleaned_words.join(" ")
          return [verb, target, nil]

        when :inventory, :help, :save, :quit, :restart, :defend, :flee
          return [verb, nil, nil]

        when :use, :give, :attack, :talk
          # DON'T remove prepositions - we need them to split target/modifier
          target, modifier = extract_target_and_modifier(words)
          return [verb, target, modifier]

        when :take, :drop, :open, :close
          # Remove prepositions for simple item commands
          cleaned_words = words.reject { |w| PREPOSITIONS.include?(w) }
          return [verb, cleaned_words.join(" "), nil]

        else
          # Remove prepositions for unknown commands
          cleaned_words = words.reject { |w| PREPOSITIONS.include?(w) }
          return [verb, cleaned_words.join(" "), nil]
        end
      end

      def find_verb(word)
        VERBS.each do |verb, synonyms|
          return verb if synonyms.include?(word)
        end
        nil
      end

      def find_direction(word)
        return nil if word.nil?

        DIRECTIONS.each do |direction, synonyms|
          return direction if synonyms.include?(word)
        end
        nil
      end

      def extract_target_and_modifier(words)
        # Look for prepositions that indicate a modifier
        connector_index = words.index { |w| %w[on with to].include?(w) }

        if connector_index
          # Get target and modifier, filtering out articles
          target_words = words[0...connector_index].reject { |w| %w[the a an].include?(w) }
          modifier_words = words[(connector_index + 1)..-1]&.reject { |w| %w[the a an].include?(w) }

          target = target_words.join(" ")
          modifier = modifier_words&.join(" ")
          [target, modifier]
        else
          # No connector found, filter out articles
          cleaned = words.reject { |w| %w[the a an].include?(w) }
          [cleaned.join(" "), nil]
        end
      end
    end
  end
end
