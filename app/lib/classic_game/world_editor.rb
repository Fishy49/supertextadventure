# frozen_string_literal: true

module ClassicGame
  # Structural edits to a world document that a text editor gets wrong:
  # renames and removals cascade through every reference, links check both
  # rooms, placements move an entity instead of duplicating it. Every method
  # appends a plain description of what it changed to #changes and raises
  # WorldEditor::Error for anything the author needs to fix first.
  class WorldEditor
    class Error < StandardError; end

    COLLECTIONS = WorldPaths::COLLECTIONS
    OPPOSITES = {
      "north" => "south", "south" => "north", "east" => "west", "west" => "east",
      "up" => "down", "down" => "up", "in" => "out", "out" => "in",
      "northeast" => "southwest", "southwest" => "northeast",
      "northwest" => "southeast", "southeast" => "northwest"
    }.freeze
    PLACEABLE = %w[item npc creature].freeze

    attr_reader :world, :changes

    def initialize(world)
      @world = world
      @changes = []
    end

    # ---- entities -----------------------------------------------------

    def add(section, id, name: nil, description: nil, in_room: nil)
      collection = collection!(section)
      check_id!(id)
      raise Error, "#{singular(section)} '#{id}' already exists" if collection.key?(id)

      entity = { "name" => name.presence || id.tr("_", " ").capitalize, "description" => description.to_s }
      entity.merge!("exits" => {}, "items" => [], "npcs" => [], "creatures" => []) if section == "rooms"
      entity["health"] = 10 if section == "creatures"
      collection[id] = entity
      changes << "added #{section}.#{id}"
      place(id, in_room) if in_room
      entity
    end

    def rename(section, id, new_id)
      collection = collection!(section)
      raise Error, "#{singular(section)} '#{id}' does not exist" unless collection.key?(id)

      check_id!(new_id)
      raise Error, "#{singular(section)} '#{new_id}' already exists" if collection.key?(new_id)

      kind = WorldPaths::SINGULAR[section]
      WorldPaths.collect_refs(world).each do |ref|
        next unless ref.kind == kind && ref.id == id

        ref.rewrite(new_id)
        changes << "updated #{ref.path}"
      end
      world[section] = collection.to_h { |k, v| [k == id ? new_id : k, v] }
      rename_layout(id, new_id) if section == "rooms"
      changes << "renamed #{section}.#{id} to #{section}.#{new_id}"
    end

    def remove(section, id)
      collection = collection!(section)
      raise Error, "#{singular(section)} '#{id}' does not exist" unless collection.key?(id)

      kind = WorldPaths::SINGULAR[section]
      WorldPaths.collect_refs(world).each do |ref|
        next unless ref.kind == kind && ref.id == id
        next if ref.path == "meta.starting_room"

        ref.remove
        changes << "removed reference at #{ref.path}"
      end
      collection.delete(id)
      world.dig("meta", "editor", "rooms")&.delete(id) if section == "rooms"
      changes << "removed #{section}.#{id}"
      return unless section == "rooms" && world.dig("meta", "starting_room") == id

      changes << "meta.starting_room still points at '#{id}'; set it to another room"
    end

    # ---- exits --------------------------------------------------------

    def link(room, direction, target, both: false)
      room!(room)
      room!(target)
      raise Error, "direction cannot be blank" if direction.blank?

      set_exit(room, direction, target)
      return unless both

      back = OPPOSITES[direction]
      raise Error, "no opposite direction for '#{direction}'; link the way back explicitly" unless back

      set_exit(target, back, room)
    end

    def unlink(room, direction)
      exits = room!(room)["exits"]
      raise Error, "room '#{room}' has no exit '#{direction}'" unless exits.is_a?(Hash) && exits.key?(direction)

      exits.delete(direction)
      changes << "removed rooms.#{room}.exits.#{direction}"
    end

    # ---- placement ----------------------------------------------------

    # Puts an item, NPC, or creature in a room, or an item inside a
    # container, taking it out of wherever it was first.
    def place(id, target)
      kind = kind_of!(id)
      unplace(id, quiet: true)
      if section("rooms").key?(target)
        list = (section("rooms")[target]["#{kind}s"] ||= [])
        list << id
        changes << "placed #{kind} '#{id}' in room '#{target}'"
      elsif kind == "item" && section("items")[target].is_a?(Hash)
        container = section("items")[target]
        unless container["is_container"] == true
          raise Error,
                "item '#{target}' is not a container (is_container is not true)"
        end

        (container["contents"] ||= []) << id
        changes << "placed item '#{id}' in container '#{target}'"
      else
        raise Error, "'#{target}' is not a room#{' or a container item' if kind == 'item'}"
      end
    end

    def unplace(id, quiet: false)
      kind = kind_of!(id)
      removed = []
      section("rooms").each do |rid, room|
        next unless room.is_a?(Hash) && room["#{kind}s"].is_a?(Array) && room["#{kind}s"].include?(id)

        room["#{kind}s"].delete(id)
        removed << "room '#{rid}'"
      end
      if kind == "item"
        section("items").each do |iid, item|
          next unless item.is_a?(Hash) && item["contents"].is_a?(Array) && item["contents"].include?(id)

          item["contents"].delete(id)
          removed << "container '#{iid}'"
        end
      end
      removed.each { |where| changes << "took #{kind} '#{id}' out of #{where}" }
      changes << "#{kind} '#{id}' was not placed anywhere" if removed.empty? && !quiet
    end

    # ---- raw paths ----------------------------------------------------

    def set(path, value)
      raise Error, "path cannot be blank" if path.blank?

      WorldPaths.set(world, path, value)
      changes << "set #{path}"
    rescue ArgumentError => e
      raise Error, e.message
    end

    def delete(path)
      raise Error, "nothing at #{path}" if WorldPaths.dig(world, path).nil?

      WorldPaths.delete(world, path)
      changes << "deleted #{path}"
    end

    # ---- batches ------------------------------------------------------

    # Applies a list of { "op" => ..., ... } hashes, the same operations the
    # CLI exposes, so an agent can make many edits in one call.
    def apply(ops)
      raise Error, "ops must be a JSON array of objects" unless ops.is_a?(Array) && ops.all?(Hash)

      ops.each_with_index do |op, i|
        apply_one(op)
      rescue Error => e
        raise Error, "op #{i + 1} (#{op['op']}): #{e.message}"
      end
    end

    private

      def apply_one(operation)
        op = operation
        case op["op"]
        when "add" then add(op["section"], op["id"], name: op["name"], description: op["description"],
                                                     in_room: op["in"])
        when "set" then set(op["path"], op["value"])
        when "del" then delete(op["path"])
        when "rename" then rename(op["section"], op["id"], op["new_id"] || op["to"])
        when "rm" then remove(op["section"], op["id"])
        when "link" then link(op["room"], op["direction"], op["to"], both: op["both"] == true)
        when "unlink" then unlink(op["room"], op["direction"])
        when "place" then place(op["id"], op["in"])
        when "unplace" then unplace(op["id"])
        else raise Error, "unknown op '#{op['op']}' (add, set, del, rename, rm, link, unlink, place, unplace)"
        end
      end

      def section(name)
        world[name] = {} unless world[name].is_a?(Hash)
        world[name]
      end

      def collection!(name)
        raise Error, "section must be one of #{COLLECTIONS.join(', ')}, not '#{name}'" unless COLLECTIONS.include?(name)

        section(name)
      end

      def singular(section)
        WorldPaths::SINGULAR[section]
      end

      def check_id!(id)
        raise Error, "id cannot be blank" if id.blank?
        raise Error, "id '#{id}' cannot contain dots or whitespace" if id.match?(/[.\s]/)
      end

      def room!(id)
        room = section("rooms")[id]
        raise Error, "room '#{id}' does not exist" unless room.is_a?(Hash)

        room
      end

      def kind_of!(id)
        kinds = PLACEABLE.select { |k| section("#{k}s")[id].is_a?(Hash) }
        raise Error, "no item, npc, or creature named '#{id}'" if kinds.empty?
        raise Error, "'#{id}' is defined as more than one of #{kinds.join(', ')}; rename one" if kinds.size > 1

        kinds.first
      end

      def set_exit(room, direction, target)
        definition = room!(room)
        definition["exits"] = {} unless definition["exits"].is_a?(Hash)
        exits = definition["exits"]
        existing = exits[direction]
        if existing.is_a?(Hash)
          existing["to"] = target
        else
          exits[direction] = target
        end
        changes << "#{existing ? 'retargeted' : 'added'} rooms.#{room}.exits.#{direction} -> #{target}"
      end

      def rename_layout(id, new_id)
        layout = world.dig("meta", "editor", "rooms")
        return unless layout.is_a?(Hash) && layout.key?(id)

        world["meta"]["editor"]["rooms"] = layout.to_h { |k, v| [k == id ? new_id : k, v] }
      end
  end
end
