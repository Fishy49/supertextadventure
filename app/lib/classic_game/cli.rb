# frozen_string_literal: true

require "optparse"

module ClassicGame
  # bin/world: build, inspect, validate, and play worlds from a shell.
  # Written for agents as much as people: every command has a --json mode,
  # exit codes are stable (0 ok, 1 the world has errors or a script failed,
  # 2 bad usage), and every edit writes the file first and then reports what
  # the validator thinks, so nothing is ever refused into a state you cannot see.
  class Cli
    include Inspect
    include Edit
    include Play

    class Usage < StandardError; end

    OK = 0
    PROBLEMS = 1
    USAGE = 2

    COMMANDS = [
      ["new", "FILE", "Create a world with one starting room", %i[name description]],
      ["check", "FILE", "Validate the contract and lint for trouble", %i[strict]],
      ["show", "FILE [PATH]", "Print a summary, or the JSON at a dotted path", []],
      ["ls", "FILE SECTION", "List rooms, items, npcs, creatures, or flags", %i[in]],
      ["graph", "FILE", "Print every room and its exits", []],
      ["refs", "FILE ID", "Print every place an id is referenced", []],
      ["add", "FILE SECTION ID", "Add a room, item, npc, or creature", %i[name description in]],
      ["set", "FILE PATH VALUE", "Set a dotted path; VALUE is parsed as JSON, else kept as a string", []],
      ["del", "FILE PATH", "Delete a dotted path", []],
      ["rename", "FILE SECTION ID NEW_ID", "Rename an entity and every reference to it", []],
      ["rm", "FILE SECTION ID", "Remove an entity and every reference to it", []],
      ["link", "FILE ROOM DIRECTION TARGET", "Add or retarget an exit", %i[both]],
      ["unlink", "FILE ROOM DIRECTION", "Remove an exit", []],
      ["place", "FILE ID TARGET", "Move an item, npc, or creature into a room, or an item into a container", []],
      ["unplace", "FILE ID", "Take an entity out of every room and container", []],
      ["apply", "FILE [OPS]", "Apply a JSON array of operations from a file, or stdin with -", []],
      ["play", "FILE", "Play the world headlessly through the real engine", %i[script commands seed]],
      ["explain", "[CODE]", "What a check code means and how to fix it", []],
      ["help", "[COMMAND]", "Show usage", []]
    ].freeze

    OPTION_HELP = {
      name: ["--name NAME", "Display name"],
      description: ["--description TEXT", "Description text"],
      in: ["--in ID", "Room (or container) to place into, or to filter by"],
      strict: ["--strict", "Exit 1 on warnings too"],
      both: ["--both", "Also add the exit back the other way"],
      script: ["--script FILE", "Walkthrough script (commands and expect lines)"],
      commands: ["--commands TEXT", "Commands separated by semicolons"],
      seed: ["--seed N", "Random seed for dice and combat (default 1 when scripted)"]
    }.freeze

    attr_reader :out, :err, :input, :options

    def initialize(argv, stdout: $stdout, stderr: $stderr, stdin: $stdin)
      @argv = argv.dup
      @out = stdout
      @err = stderr
      @input = stdin
      @options = {}
    end

    def run
      command = @argv.shift
      return help([]) if command.nil? || %w[-h --help].include?(command)

      spec = COMMANDS.find { |c| c[0] == command }
      raise Usage, "unknown command '#{command}'. Run: bin/world help" unless spec

      args = parse_options(spec)
      public_send(:"cmd_#{command}", args)
    rescue Usage, WorldEditor::Error, OptionParser::ParseError => e
      fail_usage(e.message)
    rescue Errno::ENOENT => e
      fail_usage("no such file: #{e.message.sub(/\A.*- /, '')}")
    rescue JSON::ParserError => e
      fail_usage("not valid JSON: #{e.message}")
    end

    def cmd_help(args)
      help(args)
    end

    private

      def help(args)
        if args.first
          spec = COMMANDS.find { |c| c[0] == args.first }
          raise Usage, "unknown command '#{args.first}'" unless spec

          out.puts "usage: bin/world #{spec[0]} #{spec[1]} [--json]#{spec[3].map do |o|
            " [#{OPTION_HELP[o][0]}]"
          end.join}"
          out.puts "  #{spec[2]}"
          spec[3].each { |o| out.puts "  #{OPTION_HELP[o][0].ljust(22)} #{OPTION_HELP[o][1]}" }
          return OK
        end
        out.puts "usage: bin/world COMMAND FILE [ARGS] [--json]"
        out.puts
        width = COMMANDS.map { |c| "#{c[0]} #{c[1]}".length }.max
        COMMANDS.each { |c| out.puts "  #{"#{c[0]} #{c[1]}".ljust(width)}  #{c[2]}" }
        out.puts
        out.puts "Edits write the file, then print what changed and what the validator found."
        out.puts "Exit codes: 0 ok, 1 the world has errors or a script failed, 2 bad usage."
        out.puts "Run bin/world help COMMAND for a command's options, or bin/world explain for the check codes."
        OK
      end

      def parse_options(spec)
        parser = OptionParser.new
        parser.on("--json") { options[:json] = true }
        spec[3].each do |name|
          flag, desc = OPTION_HELP[name]
          parser.on(flag, desc) { |v| options[name] = v }
        end
        parser.parse(@argv)
      end

      def json?
        options[:json] == true
      end

      def fail_usage(message)
        if json?
          out.puts JSON.generate({ "ok" => false, "error" => message })
        else
          err.puts "error: #{message}"
        end
        USAGE
      end

      def need(args, count, usage)
        raise Usage, "usage: bin/world #{usage}" if args.size < count

        args
      end

      def load_world(path)
        JSON.parse(File.read(path))
      end

      def write_world(path, world)
        File.write(path, "#{JSON.pretty_generate(world)}\n")
      end

      def emit(payload)
        out.puts JSON.generate(payload)
        OK
      end
  end
end
