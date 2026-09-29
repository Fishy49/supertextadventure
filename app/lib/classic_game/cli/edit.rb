# frozen_string_literal: true

module ClassicGame
  class Cli
    # Commands that change the file. Each one loads, edits through
    # WorldEditor, writes, then reports the changes and the validator's view.
    module Edit
      def cmd_new(args)
        file = need(args, 1, "new FILE [--name NAME] [--description TEXT]").first
        raise Usage, "#{file} already exists" if File.exist?(file)

        world = SampleWorlds::BLANK.deep_dup
        world["meta"]["name"] = options[:name] if options[:name]
        world["meta"]["description"] = options[:description] if options[:description]
        write_world(file, world)
        finish(file, world, ["created #{file}"])
      end

      def cmd_add(args)
        file, section, id = need(args, 3, "add FILE SECTION ID [--name NAME] [--description TEXT] [--in ROOM]")
        edit(file) do |e|
          e.add(section, id, name: options[:name], description: options[:description], in_room: options[:in])
        end
      end

      def cmd_set(args)
        file, path, raw = need(args, 3, "set FILE PATH VALUE")
        edit(file) { |e| e.set(path, parse_value(raw)) }
      end

      def cmd_del(args)
        file, path = need(args, 2, "del FILE PATH")
        edit(file) { |e| e.delete(path) }
      end

      def cmd_rename(args)
        file, section, id, new_id = need(args, 4, "rename FILE SECTION ID NEW_ID")
        edit(file) { |e| e.rename(section, id, new_id) }
      end

      def cmd_rm(args)
        file, section, id = need(args, 3, "rm FILE SECTION ID")
        edit(file) { |e| e.remove(section, id) }
      end

      def cmd_link(args)
        file, room, direction, target = need(args, 4, "link FILE ROOM DIRECTION TARGET [--both]")
        edit(file) { |e| e.link(room, direction, target, both: options[:both] == true) }
      end

      def cmd_unlink(args)
        file, room, direction = need(args, 3, "unlink FILE ROOM DIRECTION")
        edit(file) { |e| e.unlink(room, direction) }
      end

      def cmd_place(args)
        file, id, target = need(args, 3, "place FILE ID TARGET")
        edit(file) { |e| e.place(id, target) }
      end

      def cmd_unplace(args)
        file, id = need(args, 2, "unplace FILE ID")
        edit(file) { |e| e.unplace(id) }
      end

      def cmd_apply(args)
        file, source = need(args, 1, "apply FILE [OPS.json | -]")
        text = source.nil? || source == "-" ? input.read : File.read(source)
        ops = JSON.parse(text)
        edit(file) { |e| e.apply(ops) }
      end

      private

        def edit(file)
          world = load_world(file)
          editor = WorldEditor.new(world)
          yield editor
          write_world(file, world)
          finish(file, world, editor.changes)
        end

        # JSON when it parses (numbers, booleans, null, arrays, objects,
        # quoted strings), otherwise the raw text as a string.
        def parse_value(raw)
          JSON.parse(raw, quirks_mode: true)
        rescue JSON::ParserError
          raw
        end

        def finish(file, world, changes)
          linter = WorldLinter.new(world)
          errors = linter.errors
          if json?
            emit({ "ok" => errors.empty?, "file" => file, "changes" => changes,
                   "errors" => errors.map { |p| p.except(:target) },
                   "warnings" => linter.warnings.size, "info" => linter.infos.size })
          else
            changes.each { |c| out.puts "  #{c}" }
            out.puts "#{file}: #{errors.size} errors, #{linter.warnings.size} warnings, #{linter.infos.size} info"
            errors.each { |p| out.puts format_problem(p) }
          end
          errors.empty? ? OK : PROBLEMS
        end
    end
  end
end
