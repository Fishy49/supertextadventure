# frozen_string_literal: true

module ClassicGame
  # A scripted playthrough with assertions. The script is plain text, one
  # command per line, with blank lines and # comments ignored. Lines starting
  # with "expect" check the game instead of playing it:
  #
  #   look
  #   take rusty key
  #   expect has rusty_key
  #   north
  #   expect room hall
  #   expect flag door_open
  #   expect not flag dragon_dead
  #   expect health >= 5
  #   expect says the door swings open
  #
  # has/flag/room compare ids; health takes a number with an optional
  # comparison (=, !=, <, <=, >, >=); says looks for text in the last
  # response, ignoring case. "not" flips any check.
  class Walkthrough
    Step = Struct.new(:line, :text, :kind, :command, :response, :success, :ok, :detail, keyword_init: true)
    Result = Struct.new(:steps, :state, :seed, keyword_init: true) do
      def expectations
        steps.select { |s| s.kind == :expect }
      end

      def failures
        expectations.reject(&:ok)
      end

      def ok?
        failures.empty?
      end
    end

    CHECKS = %w[room flag has health says].freeze
    COMPARISONS = { "=" => :==, "==" => :==, "!=" => :!=, "<" => :<, "<=" => :<=, ">" => :>, ">=" => :>= }.freeze

    def self.parse(text)
      text.each_line.with_index(1).filter_map do |raw, line|
        content = raw.strip
        next if content.empty? || content.start_with?("#")

        if content.match?(/\Aexpect\b/i)
          Step.new(line: line, text: content, kind: :expect)
        else
          Step.new(line: line, text: content, kind: :command, command: content)
        end
      end
    end

    def self.run(world_data, text, seed: nil)
      new(Playthrough.new(world_data, seed: seed)).run(parse(text))
    end

    attr_reader :play

    def initialize(play)
      @play = play
    end

    def run(steps)
      steps.each do |step|
        if step.kind == :command
          turn = play.run(step.command)
          step.response = turn.response
          step.success = turn.success
        else
          check(step)
        end
      end
      Result.new(steps: steps, state: play.state, seed: play.seed)
    end

    private

      def check(step)
        words = step.text.split(/\s+/)
        words.shift
        negate = words.first&.downcase == "not"
        words.shift if negate
        kind = words.shift&.downcase
        raise ArgumentError, "line #{step.line}: expect needs one of #{CHECKS.join(', ')}" unless CHECKS.include?(kind)

        ok, detail = evaluate(kind, words)
        step.ok = negate ? !ok : ok
        step.detail = detail
      rescue ArgumentError => e
        step.ok = false
        step.detail = e.message
      end

      def evaluate(kind, words)
        state = play.state
        case kind
        when "room" then [state["room"] == words.first, "room is #{state['room']}"]
        when "flag"
          value = state["flags"][words.first]
          [!(value.nil? || value == false),
           value.nil? ? "flag #{words.first} is not set" : "flag #{words.first} is #{value.inspect}"]
        when "has" then [state["inventory"].include?(words.first),
                         "inventory: #{state['inventory'].join(', ').presence || '(empty)'}"]
        when "health" then health_check(state["health"], words)
        when "says"
          needle = words.join(" ")
          [play.last_response.downcase.include?(needle.downcase),
           "last response: #{play.last_response.strip.lines.first.to_s.strip}"]
        end
      end

      def health_check(health, words)
        op = words.size > 1 ? words[0] : "="
        number = words.last
        raise ArgumentError, "expect health needs a number" unless number&.match?(/\A-?\d+\z/)
        raise ArgumentError, "unknown comparison '#{op}'" unless COMPARISONS.key?(op)

        [health.to_i.public_send(COMPARISONS[op], number.to_i), "health is #{health}"]
      end
  end
end
