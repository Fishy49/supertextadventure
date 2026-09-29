# frozen_string_literal: true

module ClassicGame
  class Cli
    # play: run a world through the engine with no database. Input comes
    # from --script, --commands, a piped stdin, or an interactive prompt.
    module Play
      QUIT = %w[quit q].freeze

      def cmd_play(args)
        file = need(args, 1, "play FILE [--script FILE | --commands \"a; b\"] [--seed N] [--json]").first
        world = load_world(file)
        script = script_text
        return interactive(world) if script.nil?

        seed = (options[:seed] || 1).to_i
        result = Walkthrough.run(world, script, seed: seed)
        json? ? emit_result(result) : print_result(world, result)
        result.ok? ? OK : PROBLEMS
      end

      private

        def script_text
          return File.read(options[:script]) if options[:script]
          return options[:commands].split(";").map(&:strip).reject(&:empty?).join("\n") if options[:commands]
          return input.read unless input.respond_to?(:tty?) && input.tty?

          nil
        end

        def interactive(world)
          play = Playthrough.new(world, seed: options[:seed]&.to_i)
          out.puts play.intro
          loop do
            out.print "\n> "
            out.flush
            line = input.gets
            break if line.nil?

            command = line.strip
            next if command.empty?
            break if QUIT.include?(command.downcase)

            out.puts play.run(command).response
          end
          out.puts
          print_state(play.state)
          OK
        end

        def print_result(world, result)
          out.puts Playthrough.new(world).intro
          result.steps.each do |step|
            if step.kind == :command
              out.puts "\n> #{step.command}"
              out.puts step.response
            else
              mark = step.ok ? "ok  " : "FAIL"
              out.puts "\n[#{mark}] line #{step.line}: #{step.text}#{"  (#{step.detail})" unless step.ok}"
            end
          end
          out.puts
          print_state(result.state)
          failures = result.failures
          passed = result.expectations.size - failures.size
          out.puts "seed #{result.seed}: #{passed} of #{result.expectations.size} expectations passed"
        end

        def print_state(state)
          out.puts "--- state ---"
          out.puts "room: #{state['room']}"
          out.puts "inventory: #{state['inventory'].join(', ').presence || '(empty)'}"
          out.puts "health: #{state['health']}/#{state['max_health']}"
          flags = state["flags"].select { |_, v| v }.keys
          out.puts "flags: #{flags.join(', ').presence || '(none)'}"
          out.puts "turns: #{state['turns']}"
          out.puts "in combat" if state["in_combat"]
          out.puts "dice roll pending" if state["pending_roll"]
          out.puts "dead" if state["dead"]
        end

        def emit_result(result)
          emit({
                 "ok" => result.ok?, "seed" => result.seed,
                 "steps" => result.steps.map do |s|
                   s.to_h.except(:kind).merge("kind" => s.kind.to_s).compact.transform_keys(&:to_s)
                 end,
                 "state" => result.state
               })
        end
    end
  end
end
