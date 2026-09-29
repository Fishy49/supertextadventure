# frozen_string_literal: true

module ClassicGame
  # Dotted-path helpers over a world document, shared by the validator, the
  # linter, the editor, and the CLI. Paths look like rooms.cellar.exits.north;
  # * matches every key of an object or every index of an array.
  module WorldPaths
    COLLECTIONS = %w[rooms items npcs creatures].freeze
    SINGULAR = { "rooms" => "room", "items" => "item", "npcs" => "npc", "creatures" => "creature" }.freeze
    # Reference kinds that are not entity collections.
    LOOSE_KINDS = %w[flag topic].freeze

    # One place an id is used, found by walking a rule from the refs table.
    # kind is the singular entity type (room, item, npc, creature) or flag or
    # topic. trail is the list of [node, key] pairs from the root to the value,
    # so a reference can rewrite or remove itself.
    Ref = Struct.new(:rule, :kind, :mode, :scope, :id, :path, :segments, :trail, keyword_init: true) do
      def owner
        WorldPaths.owner_of(segments)
      end

      def rewrite(new_id)
        parent, key = trail.last
        parent[key] = new_id
        path
      end

      # Drops the reference: an array entry is deleted, an exit whose "to"
      # points at the id loses the whole exit, and any other key is removed.
      # The starting room is left alone so the validator reports it loudly.
      def remove
        return if rule["path"] == "meta.starting_room"

        if rule["path"] == "rooms.*.exits.*.to"
          node, key = trail[-2]
          node.delete(key)
          return
        end
        node, key = trail.last
        node.is_a?(Array) ? node.delete(id) : node.delete(key)
      end
    end

    module_function

    # Yields [dotted_path, value, trail] for every value the segments reach.
    def each_at(node, segments, trail = [], &)
      if segments.empty?
        yield trail.map { |_, k| k.to_s }.join("."), node, trail
        return
      end

      seg = segments.first
      rest = segments.drop(1)
      if seg == "*"
        case node
        when Hash then node.each_key { |k| each_at(node[k], rest, trail + [[node, k]], &) }
        when Array then node.each_index { |i| each_at(node[i], rest, trail + [[node, i]], &) }
        end
      elsif node.is_a?(Hash) && node.key?(seg)
        each_at(node[seg], rest, trail + [[node, seg]], &)
      end
    end

    # Every reference in the world according to the refs table, as Ref records.
    def collect_refs(world, rules = WorldValidator.refs)
      out = []
      rules.each do |rule|
        each_at(world, rule["path"].split(".")) do |path, value, trail|
          next unless value.is_a?(String)

          kind = LOOSE_KINDS.include?(rule["kind"]) ? rule["kind"] : SINGULAR.fetch(rule["kind"])
          out << Ref.new(rule: rule, kind: kind, mode: rule["mode"] || "ref", scope: rule["scope"], id: value,
                         path: path, segments: path.split("."), trail: trail)
        end
      end
      out
    end

    # Which entity a path belongs to: rooms.x.exits.n -> { type: "room", id: "x" }.
    def owner_of(segments)
      s = segments.is_a?(Array) ? segments : segments.to_s.split(".")
      return { type: "meta", id: "meta" } if s[0] == "meta"
      return { type: SINGULAR[s[0]], id: s[1] } if COLLECTIONS.include?(s[0]) && s[1]

      { type: "meta", id: "meta" }
    end

    # Reads a dotted path. Array segments must be integers.
    def dig(world, path)
      path.to_s.split(".").reduce(world) do |node, seg|
        case node
        when Hash then node.key?(seg) ? node[seg] : (return nil)
        when Array then seg.match?(/\A\d+\z/) ? node[seg.to_i] : (return nil)
        else return nil
        end
      end
    end

    # Writes a dotted path, creating intermediate objects as needed.
    def set(world, path, value)
      segments = path.to_s.split(".")
      raise ArgumentError, "empty path" if segments.empty?

      parent = segments[0..-2].reduce(world) do |node, seg|
        child = step(node, seg)
        if child.nil?
          child = {}
          assign(node, seg, child)
        end
        child
      end
      assign(parent, segments.last, value)
    end

    # Deletes a dotted path. Returns the removed value, or nil if nothing was there.
    def delete(world, path)
      segments = path.to_s.split(".")
      parent = segments[0..-2].reduce(world) { |node, seg| node.nil? ? nil : step(node, seg) }
      last = segments.last
      case parent
      when Hash then parent.delete(last)
      when Array then last.match?(/\A\d+\z/) ? parent.delete_at(last.to_i) : nil
      end
    end

    def step(node, seg)
      case node
      when Hash then node[seg]
      when Array then seg.match?(/\A\d+\z/) ? node[seg.to_i] : nil
      end
    end

    def assign(node, seg, value)
      case node
      when Hash then node[seg] = value
      when Array
        raise ArgumentError, "#{seg} is not an array index" unless seg.match?(/\A\d+\z/)

        node[seg.to_i] = value
      else
        raise ArgumentError, "cannot set #{seg} on #{node.class.name.downcase}"
      end
    end
  end
end
