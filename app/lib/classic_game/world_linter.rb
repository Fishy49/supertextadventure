# frozen_string_literal: true

module ClassicGame
  # Everything worth telling an author about a world that the contract does
  # not reject: unreachable rooms, items nobody can pick up, locks with no key,
  # flags that are checked but never set. Contract errors are included at
  # level "error" so one call gives the whole picture.
  #
  #   ClassicGame::WorldLinter.new(world_data).problems
  #   # => [{ code: "item.unplaced", level: "warn", path: "items.rope",
  #   #       message: "...", target: { type: "item", id: "rope" } }]
  #
  # app/javascript/world_builder/contract.js (lintWorld) produces the same
  # codes and paths; ContractParityTest proves it over the fixture corpus.
  class WorldLinter
    LEVELS = %w[error warn info].freeze
    LINT_CODES = %w[
      flag.never_set flag.never_checked
      exit.key_unplaced exit.flag_never_set exit.redundant_use_item room.unreachable room.describes_takeable
      item.unplaced item.message_without_text item.reveals_unknown_exit
      container.no_unlock container.locked_but_open item.contents_without_container item.consumable_not_takeable
      movement.bad_duration
      npc.unplaced dialogue.empty topic.no_text topic.no_keywords topic.gated_without_locked_text
      npc.gives_without_accepts
      creature.unplaced creature.condition_without_hostile
    ].freeze

    attr_reader :world

    def initialize(world_data)
      @validator = WorldValidator.new(world_data)
      @world = @validator.world
    end

    def problems
      @problems ||= contract_problems + lint_problems
    end

    def errors
      problems.select { |p| p[:level] == "error" }
    end

    def warnings
      problems.select { |p| p[:level] == "warn" }
    end

    def infos
      problems.select { |p| p[:level] == "info" }
    end

    # Only the advisory problems, without the contract errors.
    def lint_problems
      @lint_problems ||= begin
        @out = []
        index!
        lint_flags
        lint_rooms
        lint_items
        lint_npcs
        lint_creatures
        @out
      end
    end

    private

      def contract_problems
        @validator.errors.map do |e|
          { code: e[:code], level: "error", path: e[:path], message: e[:message],
            target: WorldPaths.owner_of(e[:path]) }
        end
      end

      def section(name)
        value = world[name]
        value.is_a?(Hash) ? value : {}
      end

      # JavaScript truthiness, so the Ruby and JS linters agree on odd values.
      def truthy?(value)
        return false if value.nil? || value == false || value == ""

        !(value.is_a?(Numeric) && value.zero?)
      end

      def entity_name(type, id)
        e = section("#{type}s")[id]
        e.is_a?(Hash) && truthy?(e["name"]) ? e["name"] : id
      end

      def report(level, code, path, message, target = nil)
        @out << { code: code, level: level, path: path, message: message, target: target || WorldPaths.owner_of(path) }
      end

      def index!
        @refs = WorldPaths.collect_refs(world)
        @placed = { "item" => Set.new, "npc" => Set.new, "creature" => Set.new }
        @refs.each { |r| @placed[r.kind]&.add(r.id) if r.mode == "place" }
        @flags = {}
        @refs.each do |r|
          next unless r.kind == "flag"

          entry = (@flags[r.id] ||= { set: [], check: [] })
          entry[r.mode == "set" ? :set : :check] << r
        end
        @hidden_dirs = Set.new
        @reachable = compute_reachable
      end

      def flag_set?(flag)
        @flags.key?(flag) && @flags[flag][:set].any?
      end

      def compute_reachable
        rooms = section("rooms")
        start = section("meta")["starting_room"]
        seen = Set.new
        return seen unless truthy?(rooms[start])

        queue = [start]
        seen << start
        until queue.empty?
          room = rooms[queue.shift]
          next unless room.is_a?(Hash)

          exits = room["exits"].is_a?(Hash) ? room["exits"] : {}
          exits.each_value do |ex|
            to = if ex.is_a?(String)
                   ex
                 else
                   (ex.is_a?(Hash) ? ex["to"] : nil)
                 end
            next unless truthy?(to) && truthy?(rooms[to]) && seen.exclude?(to)

            seen << to
            queue << to
          end
        end
        seen
      end

      def lint_flags
        @flags.each do |flag, entry|
          target = { type: "flag", id: flag }
          if entry[:set].empty?
            where = entry[:check].map(&:path).join(", ")
            report("warn", "flag.never_set", entry[:check].map(&:path).min,
                   "Flag \"#{flag}\" is checked but nothing ever sets it (#{where}).", target)
          elsif entry[:check].empty?
            report("info", "flag.never_checked", entry[:set].map(&:path).min,
                   "Flag \"#{flag}\" is set but never checked.", target)
          end
        end
      end

      def lint_rooms
        rooms = section("rooms")
        start = section("meta")["starting_room"]
        rooms.each do |rid, room|
          next unless room.is_a?(Hash)

          exits = room["exits"].is_a?(Hash) ? room["exits"] : {}
          exits.each { |direction, exit_def| lint_exit(rid, direction, exit_def) if exit_def.is_a?(Hash) }
          lint_room_prose(rid, room)
          next unless truthy?(start) && truthy?(rooms[start]) && @reachable.exclude?(rid)

          report("warn", "room.unreachable", "rooms.#{rid}", "Room is unreachable from the starting room by any exit.")
        end
      end

      # Room text never changes, so prose that names a takeable item still
      # describes it after the player has pocketed it.
      def lint_room_prose(rid, room)
        return unless room["description"].is_a?(String) && room["items"].is_a?(Array)

        text = room["description"].downcase
        room["items"].each do |iid|
          item = section("items")[iid]
          next unless item.is_a?(Hash) && item["takeable"] != false

          term = mentioned_term(text, item)
          next unless term

          report("info", "room.describes_takeable", "rooms.#{rid}.description",
                 "Description mentions \"#{term}\", but #{entity_name('item', iid)} is takeable " \
                 "and the text will not change once it is taken.")
        end
      end

      def mentioned_term(text, item)
        terms = [item["name"]] + (item["keywords"].is_a?(Array) ? item["keywords"] : [])
        terms.find { |t| t.is_a?(String) && !t.empty? && text.match?(/\b#{Regexp.escape(t.downcase)}\b/) }
      end

      def lint_exit(rid, direction, exit_def)
        base = "rooms.#{rid}.exits.#{direction}"
        @hidden_dirs << direction if truthy?(exit_def["hidden"])
        key_field = truthy?(exit_def["use_item"]) ? "use_item" : "requires"
        key = exit_def[key_field]
        if truthy?(key) && section("items")[key].is_a?(Hash) && @placed["item"].exclude?(key)
          report("warn", "exit.key_unplaced", "#{base}.#{key_field}",
                 "Exit #{direction} is locked and its key \"#{entity_name('item', key)}\" is never placed anywhere.")
        end
        if truthy?(exit_def["requires_flag"]) && !flag_set?(exit_def["requires_flag"])
          report("warn", "exit.flag_never_set", "#{base}.requires_flag",
                 "Exit #{direction} is gated on flag \"#{exit_def['requires_flag']}\", which nothing ever sets.")
        end
        use_item = exit_def["use_item"]
        return unless truthy?(use_item) && truthy?(exit_def["requires"]) && use_item == exit_def["requires"]

        report("info", "exit.redundant_use_item", base,
               "Exit #{direction} sets both requires and use_item to the same item; " \
               "requires alone already lets the player through.")
      end

      def lint_items
        section("items").each do |iid, item|
          next unless item.is_a?(Hash)

          base = "items.#{iid}"
          unless @placed["item"].include?(iid)
            report("warn", "item.unplaced", base,
                   "Item is never placed: not in a room, container, loot list, or given by an NPC.")
          end
          on_use = item["on_use"]
          if on_use.is_a?(Hash) && on_use["type"] == "message" && !truthy?(on_use["text"])
            report("warn", "item.message_without_text", "#{base}.on_use", "on_use of type message has no text.")
          end
          lint_reveals(base, item)
          lint_container(base, item)
          if !truthy?(item["is_container"]) && item["contents"].is_a?(Array) && item["contents"].any?
            report("warn", "item.contents_without_container", base, "Item has contents but is_container is not true.")
          end
          next unless item["takeable"] == false && truthy?(item["consumable"])

          report("info", "item.consumable_not_takeable", base,
                 "Item is not takeable but is consumable; it can only be used from the floor.")
        end
      end

      def lint_reveals(base, item)
        reveals = item["reveals_exit"]
        if reveals.is_a?(Hash) && truthy?(reveals["direction"]) && @hidden_dirs.exclude?(reveals["direction"])
          report("warn", "item.reveals_unknown_exit", "#{base}.reveals_exit",
                 "reveals_exit \"#{reveals['direction']}\" but no room has a hidden exit in that direction.")
        end
        examine = item["on_examine"]
        return unless examine.is_a?(Hash) && truthy?(examine["reveals_exit"])
        return if @hidden_dirs.include?(examine["reveals_exit"])

        report("warn", "item.reveals_unknown_exit", "#{base}.on_examine",
               "on_examine reveals \"#{examine['reveals_exit']}\" but no room has a hidden exit in that direction.")
      end

      def lint_container(base, item)
        return unless truthy?(item["is_container"]) && truthy?(item["locked"])

        items = section("items")
        unlock_item = item["unlock_item"]
        unlock_flag = item["unlock_flag"]
        item_ok = truthy?(unlock_item) && items[unlock_item].is_a?(Hash) && @placed["item"].include?(unlock_item)
        flag_ok = truthy?(unlock_flag) && flag_set?(unlock_flag)
        reasons = []
        if !truthy?(unlock_item) && !truthy?(unlock_flag)
          reasons << "no unlock_item or unlock_flag"
        else
          if truthy?(unlock_item) && !item_ok
            reasons << if items[unlock_item].is_a?(Hash)
                         "unlock item \"#{entity_name('item', unlock_item)}\" is never placed"
                       else
                         "unlock item \"#{unlock_item}\" does not exist"
                       end
          end
          reasons << "flag \"#{unlock_flag}\" is never set" if truthy?(unlock_flag) && !flag_ok
        end
        if !item_ok && !flag_ok
          report("warn", "container.no_unlock", base,
                 "Container is locked and nothing can unlock it (#{reasons.join('; ')}).")
        end
        return unless item["starts_closed"] == false

        report("warn", "container.locked_but_open", base,
               "Container is locked but starts open (starts_closed: false), so the lock never engages.")
      end

      def lint_patrol(base, movement)
        return unless movement.is_a?(Hash) && movement["type"] == "patrol" && movement["schedule"].is_a?(Array)

        movement["schedule"].each_with_index do |stop, i|
          next unless stop.is_a?(Hash)
          next if stop["duration"].is_a?(Numeric) && stop["duration"].positive?

          report("warn", "movement.bad_duration", "#{base}.movement.schedule.#{i}",
                 "Patrol stop #{i + 1} should have a positive duration in turns.")
        end
      end

      def movement?(entity)
        entity["movement"].is_a?(Hash) && truthy?(entity["movement"]["type"])
      end

      def lint_npcs
        section("npcs").each do |nid, npc|
          next unless npc.is_a?(Hash)

          base = "npcs.#{nid}"
          if @placed["npc"].exclude?(nid) && !movement?(npc)
            report("warn", "npc.unplaced", base, "NPC is not placed in any room and has no movement.")
          end
          lint_dialogue(base, npc["dialogue"]) if npc["dialogue"].is_a?(Hash)
          if truthy?(npc["gives_item"]) && !truthy?(npc["accepts_item"])
            report("warn", "npc.gives_without_accepts", base, "gives_item without accepts_item never triggers.")
          end
          lint_patrol(base, npc["movement"])
        end
      end

      def lint_dialogue(base, dialogue)
        if !truthy?(dialogue["greeting"]) && !truthy?(dialogue["default"])
          report("warn", "dialogue.empty", "#{base}.dialogue",
                 "Dialogue has neither greeting nor default; \"talk to\" will say nothing useful.")
        end
        topics = dialogue["topics"].is_a?(Hash) ? dialogue["topics"] : {}
        topics.each do |tk, topic|
          next unless topic.is_a?(Hash)

          path = "#{base}.dialogue.topics.#{tk}"
          report("warn", "topic.no_text", path, "Topic \"#{tk}\" has no text.") unless truthy?(topic["text"])
          unless topic["keywords"].is_a?(Array) && topic["keywords"].any?
            report("warn", "topic.no_keywords", path,
                   "Topic \"#{tk}\" has no keywords, so players cannot ask about it.")
          end
          unless (truthy?(topic["requires_flag"]) || truthy?(topic["requires_item"])) && !truthy?(topic["locked_text"])
            next
          end

          report("info", "topic.gated_without_locked_text", path, "Topic \"#{tk}\" is gated but has no locked_text.")
        end
      end

      def lint_creatures
        section("creatures").each do |cid, creature|
          next unless creature.is_a?(Hash)

          base = "creatures.#{cid}"
          if @placed["creature"].exclude?(cid) && !movement?(creature)
            report("warn", "creature.unplaced", base, "Creature is not placed in any room and has no movement.")
          end
          if truthy?(creature["attack_condition"]) && !truthy?(creature["hostile"])
            report("info", "creature.condition_without_hostile", base,
                   "attack_condition has no effect unless hostile is true.")
          end
          lint_patrol(base, creature["movement"])
        end
      end
  end
end
