# frozen_string_literal: true

module ClassicGame
  class Cli
    # Read-only commands: check, show, ls, graph, refs, explain.
    module Inspect
      EXPLANATIONS = {
        "schema.invalid" => ["The value does not match the world schema at that path.",
                             "Run bin/world show FILE PATH and compare with public/contract/world.schema.json."],
        "starting_room.missing" => ["meta.starting_room is absent or names a room that does not exist.",
                                    "Set it to a real room id: bin/world set FILE meta.starting_room ROOM."],
        "ref.missing" => ["The path names a room, item, npc, or creature that is not defined.",
                          "Add the entity, or fix the id. bin/world ls FILE SECTION shows what exists."],
        "topic.missing" => ["leads_to or unlocks_dialogue names a dialogue topic no NPC defines.",
                            "Use a key from that NPC's dialogue.topics."],
        "dice.outcomes" => ["A dice_roll needs both on_success and on_failure.",
                            "Add the missing branch, even if it only carries a message."],
        "dice.consume_on" => ["consume_on must be failure, success, or any.", "Pick one of those three."],
        "attack_condition.invalid" => ["attack_condition takes exactly one of moves, room_entries, on_talk.",
                                       "Keep a single key. Unknown keys make the creature never attack."],
        "flag.never_set" => ["Something checks this flag but nothing sets it, so the check can never pass.",
                             "Add sets_flag somewhere (an exit, item on_use, dialogue topic, creature defeat)."],
        "flag.never_checked" => ["A flag is set but nothing reads it.", "Harmless; remove it or gate something on it."],
        "exit.key_unplaced" => ["The exit needs an item the player can never obtain.",
                                "Place the key: bin/world place FILE ITEM ROOM."],
        "exit.flag_never_set" => ["The exit is gated on a flag nothing sets.",
                                  "Add a sets_flag that the player can reach."],
        "exit.redundant_use_item" => ["requires and use_item name the same item, and requires alone is enough.",
                                      "Drop one of them."],
        "room.unreachable" => ["No chain of exits leads here from the starting room.",
                               "Link it: bin/world link FILE FROM DIRECTION ROOM --both."],
        "room.describes_takeable" => ["The description names an item the player can take, and room text never changes.",
                                      "Describe the spot, not the item; the You see line shows what is really there."],
        "item.unplaced" => ["The item exists but is not in any room, container, loot list, or NPC gift.",
                            "Place it, or remove it: bin/world rm FILE items ID."],
        "item.message_without_text" => ["on_use is type message but has no text.", "Add on_use.text."],
        "item.reveals_unknown_exit" => ["The item reveals a direction no room hides.",
                                        "Mark the exit hidden: true, or fix the direction."],
        "container.no_unlock" => ["The container is locked and nothing can open it.",
                                  "Set unlock_item to a placed item, or unlock_flag to a flag something sets."],
        "container.locked_but_open" => ["locked is true but starts_closed is false, so the lock never engages.",
                                        "Remove starts_closed: false."],
        "item.contents_without_container" => ["contents is set but is_container is not true.",
                                              "Set is_container: true."],
        "item.consumable_not_takeable" => ["The item cannot be picked up but can be consumed.",
                                           "Usually fine; make it takeable if players should carry it."],
        "movement.bad_duration" => ["A patrol stop needs a positive duration in turns.", "Set duration to 1 or more."],
        "npc.unplaced" => ["The NPC is in no room and has no movement.", "Place it: bin/world place FILE NPC ROOM."],
        "dialogue.empty" => ["Dialogue has neither greeting nor default, so talking says nothing.",
                             "Add dialogue.greeting."],
        "topic.no_text" => ["The topic has no text to say.", "Add text."],
        "topic.no_keywords" => ["Players ask about topics by keyword, and this topic has none.", "Add keywords."],
        "topic.gated_without_locked_text" => ["The topic is gated but has no locked_text.",
                                              "Add locked_text so players learn they are missing something."],
        "npc.gives_without_accepts" => ["gives_item only triggers after accepts_item is given.", "Add accepts_item."],
        "creature.unplaced" => ["The creature is in no room and has no movement.",
                                "Place it: bin/world place FILE CREATURE ROOM."],
        "creature.condition_without_hostile" => ["attack_condition does nothing unless hostile is true.",
                                                 "Set hostile: true or drop the condition."]
      }.freeze

      def cmd_check(args)
        file = need(args, 1, "check FILE [--strict] [--json]").first
        linter = WorldLinter.new(load_world(file))
        report_check(file, linter)
        failed = linter.errors.any? || (options[:strict] && linter.warnings.any?)
        failed ? PROBLEMS : OK
      end

      def cmd_show(args)
        file, path = need(args, 1, "show FILE [PATH]")
        world = load_world(file)
        if path
          value = WorldPaths.dig(world, path)
          raise Usage, "nothing at #{path}" if value.nil?

          out.puts(value.is_a?(Hash) || value.is_a?(Array) ? JSON.pretty_generate(value) : JSON.generate(value))
          return OK
        end
        summary = world_summary(world)
        return emit(summary) if json?

        out.puts "#{summary['name']} (#{file})"
        out.puts "  #{summary['description']}" if summary["description"].present?
        out.puts "  starting room: #{summary['starting_room']}"
        out.puts "  rooms #{summary['counts']['rooms']}, items #{summary['counts']['items']}, " \
                 "npcs #{summary['counts']['npcs']}, creatures #{summary['counts']['creatures']}, " \
                 "flags #{summary['counts']['flags']}"
        out.puts "  check: #{summary['check']}"
        OK
      end

      def cmd_ls(args)
        file, section = need(args, 2, "ls FILE SECTION [--in ROOM]")
        world = load_world(file)
        rows = section == "flags" ? flag_rows(world) : entity_rows(world, section)
        rows = rows.select { |r| Array(r["in"]).include?(options[:in]) } if options[:in]
        return emit(rows) if json?

        rows.each do |r|
          extra = r["exits"] ? "exits: #{r['exits'].join(', ')}" : r["in"] && "in: #{r['in'].join(', ')}"
          extra = "set #{r['set']}, checked #{r['check']}" if section == "flags"
          out.puts [r["id"], r["name"], extra].compact.join("\t")
        end
        OK
      end

      def cmd_graph(args)
        file = need(args, 1, "graph FILE").first
        world = load_world(file)
        graph = exit_graph(world)
        return emit(graph) if json?

        graph.each do |id, room|
          out.puts "#{id}  #{room['name']}#{'  (unreachable)' unless room['reachable']}"
          room["exits"].each do |dir, ex|
            notes = []
            notes << "hidden" if ex["hidden"]
            notes << "requires #{ex['requires']}" if ex["requires"]
            notes << "use #{ex['use_item']}" if ex["use_item"]
            notes << "flag #{ex['requires_flag']}" if ex["requires_flag"]
            out.puts "  #{dir} -> #{ex['to']}#{"  [#{notes.join(', ')}]" if notes.any?}"
          end
        end
        OK
      end

      def cmd_refs(args)
        file, id = need(args, 2, "refs FILE ID")
        world = load_world(file)
        hits = WorldPaths.collect_refs(world).select { |r| r.id == id }
                         .map { |r| { "path" => r.path, "kind" => r.kind, "mode" => r.mode } }
        return emit(hits) if json?

        hits.each { |h| out.puts "#{h['path']}\t#{h['kind']} #{h['mode']}" }
        out.puts "no references to '#{id}'" if hits.empty?
        OK
      end

      def cmd_explain(args)
        code = args.first
        if code.nil?
          if json?
            return emit(EXPLANATIONS.transform_values do |(meaning, fix)|
              { "meaning" => meaning, "fix" => fix }
            end)
          end

          width = EXPLANATIONS.keys.map(&:length).max
          EXPLANATIONS.each { |c, (meaning, _)| out.puts "#{c.ljust(width)}  #{meaning}" }
          return OK
        end
        meaning, fix = EXPLANATIONS[code]
        raise Usage, "unknown code '#{code}'. Run bin/world explain to list them." unless meaning
        return emit({ "code" => code, "meaning" => meaning, "fix" => fix }) if json?

        out.puts code
        out.puts "  #{meaning}"
        out.puts "  fix: #{fix}"
        OK
      end

      private

        def report_check(file, linter)
          problems = linter.problems
          counts = { "error" => linter.errors.size, "warn" => linter.warnings.size, "info" => linter.infos.size }
          if json?
            return emit({ "file" => file, "ok" => linter.errors.empty?, "counts" => counts,
                          "problems" => problems.map { |p| p.except(:target) } })
          end

          out.puts "#{file}: #{counts['error']} errors, #{counts['warn']} warnings, #{counts['info']} info"
          order = WorldLinter::LEVELS
          problems.sort_by.with_index { |p, i| [order.index(p[:level]), i] }.each { |p| out.puts format_problem(p) }
        end

        def format_problem(problem)
          "  #{problem[:level].ljust(5)} #{problem[:code].ljust(34)} #{problem[:path]}\n        #{problem[:message]}"
        end

        def world_summary(world)
          linter = WorldLinter.new(world)
          meta = world["meta"].is_a?(Hash) ? world["meta"] : {}
          counts = WorldPaths::COLLECTIONS.index_with { |c| world[c].is_a?(Hash) ? world[c].size : 0 }
          counts["flags"] = WorldPaths.collect_refs(world).select { |r| r.kind == "flag" }.map(&:id).uniq.size
          {
            "name" => meta["name"], "description" => meta["description"], "starting_room" => meta["starting_room"],
            "counts" => counts,
            "check" => "#{linter.errors.size} errors, #{linter.warnings.size} warnings, #{linter.infos.size} info"
          }
        end

        def entity_rows(world, section)
          unless WorldPaths::COLLECTIONS.include?(section)
            raise Usage, "SECTION must be rooms, items, npcs, creatures, or flags"
          end

          collection = world[section].is_a?(Hash) ? world[section] : {}
          placements = placements_by_id(world)
          collection.map do |id, entity|
            row = { "id" => id, "name" => entity.is_a?(Hash) ? entity["name"] : nil }
            if section == "rooms"
              exits = entity.is_a?(Hash) && entity["exits"].is_a?(Hash) ? entity["exits"].keys : []
              row["exits"] = exits
            else
              row["in"] = placements.fetch(id, [])
            end
            row
          end
        end

        # id -> the rooms and containers that hold it at the start of the game.
        def placements_by_id(world)
          holders = Hash.new { |h, k| h[k] = [] }
          WorldPaths.collect_refs(world).each do |r|
            next unless r.mode == "place"

            holder = case r.rule["path"]
                     when /\Arooms\.\*\.(items|npcs|creatures)\.\*\z/, "items.*.contents.*" then r.segments[1]
                     when "creatures.*.loot.*" then "loot of #{r.segments[1]}"
                     when "npcs.*.gives_item" then "given by #{r.segments[1]}"
                     end
            holders[r.id] << holder if holder
          end
          holders
        end

        def flag_rows(world)
          index = {}
          WorldPaths.collect_refs(world).each do |r|
            next unless r.kind == "flag"

            entry = (index[r.id] ||= { "id" => r.id, "set" => 0, "check" => 0, "in" => [] })
            entry[r.mode == "set" ? "set" : "check"] += 1
            entry["in"] << r.path
          end
          index.values
        end

        def exit_graph(world)
          rooms = world["rooms"].is_a?(Hash) ? world["rooms"] : {}
          problems = WorldLinter.new(world).lint_problems
          unreachable = problems.filter_map { |p| p[:target][:id] if p[:code] == "room.unreachable" }
          rooms.to_h do |id, room|
            exits = room.is_a?(Hash) && room["exits"].is_a?(Hash) ? room["exits"] : {}
            edges = exits.to_h do |dir, ex|
              edge = ex.is_a?(Hash) ? ex.slice("to", "hidden", "requires", "use_item", "requires_flag") : { "to" => ex }
              [dir, edge]
            end
            [id,
             { "name" => room.is_a?(Hash) ? room["name"] : nil, "reachable" => unreachable.exclude?(id),
               "exits" => edges }]
          end
        end
    end
  end
end
