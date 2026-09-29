# frozen_string_literal: true

require "json_schemer"

module ClassicGame
  # Validates a world document against the shared contract: the JSON Schema in
  # contract/world.schema.json for shape, and contract/world.refs.json for
  # cross-references between ids. Both files are data so other implementations
  # (the browser world builder) can consume the same contract.
  #
  #   ClassicGame::WorldValidator.new(world_data).errors
  #   # => [{ code: "ref.missing", path: "rooms.bridge.exits.west.to", message: "..." }]
  class WorldValidator
    CONTRACT_DIR = Rails.root.join("app/lib/classic_game/contract")
    COLLECTIONS = %w[rooms items npcs creatures].freeze
    SINGULAR = { "rooms" => "room", "items" => "item", "npcs" => "NPC", "creatures" => "creature" }.freeze
    CONSUME_ON = %w[failure success any].freeze

    class << self
      # The parsed contract files, for embedding in pages that run the JavaScript validator.
      def schema_document
        @schema_document ||= JSON.parse(File.read(CONTRACT_DIR.join("world.schema.json")))
      end

      def refs_document
        @refs_document ||= JSON.parse(File.read(CONTRACT_DIR.join("world.refs.json")))
      end

      def schema
        @schema ||= JSONSchemer.schema(schema_document)
      end

      def refs
        @refs ||= refs_document.fetch("refs")
      end
    end

    attr_reader :world

    def initialize(world_data)
      @world = normalize(world_data)
    end

    def errors
      @errors ||= schema_errors + reference_errors
    end

    def valid?
      errors.empty?
    end

    def messages
      errors.pluck(:message)
    end

    private

      def normalize(data)
        data = JSON.parse(data) if data.is_a?(String)
        return {} unless data.is_a?(Hash)

        data.deep_stringify_keys
      end

      # ---- shape --------------------------------------------------------

      def schema_errors
        self.class.schema.validate(world).map { |e| schema_error(e) }
      end

      def schema_error(err)
        pointer = err["data_pointer"].to_s
        path = pointer.delete_prefix("/").tr("/", ".")
        { code: schema_code(err, pointer), path: path, message: schema_message(err, path) }
      end

      def schema_code(err, pointer)
        missing = Array(err.dig("details", "missing_keys"))
        return "starting_room.missing" if pointer == "/meta" && missing.include?("starting_room")
        return "attack_condition.invalid" if pointer.match?(%r{\A/creatures/[^/]+/attack_condition})
        return "dice.consume_on" if pointer.end_with?("/dice_roll/consume_on")
        return "dice.outcomes" if pointer.end_with?("/dice_roll") && missing.intersect?(%w[on_success on_failure])

        "schema.invalid"
      end

      def schema_message(err, path)
        pointer = err["data_pointer"].to_s
        item_id = pointer[%r{\A/items/([^/]+)/dice_roll}, 1]
        if item_id && err["type"] == "required" && Array(err.dig("details",
                                                                 "missing_keys")).intersect?(%w[on_success on_failure])
          return "Item '#{item_id}' has a dice_roll missing on_success or on_failure."
        end
        if item_id && pointer.end_with?("/dice_roll/consume_on")
          return "Item '#{item_id}' has invalid consume_on '#{err['data']}' (must be: #{CONSUME_ON.join(', ')})."
        end

        detail = err["error"].presence || "#{err['type']} constraint failed"
        path.empty? ? detail : "#{path}: #{detail}"
      end

      # ---- references ---------------------------------------------------

      def reference_errors
        out = []
        self.class.refs.each do |rule|
          each_at(world, rule["path"].split("."), []) do |path, value|
            next unless value.is_a?(String)
            next if rule["when"] == "string" && !value.is_a?(String)

            error = check_reference(rule, path, value)
            out << error if error
          end
        end
        out
      end

      def check_reference(rule, path, value)
        kind = rule["kind"]
        case kind
        when "flag" then nil
        when "topic" then topic_error(rule, path, value)
        else
          return nil if world.dig(kind, value).is_a?(Hash)

          code = path == "meta.starting_room" ? "starting_room.missing" : "ref.missing"
          { code: code, path: path, message: "#{path} refers to #{SINGULAR[kind]} '#{value}', which is not defined." }
        end
      end

      def topic_error(rule, path, value)
        found = if rule["scope"] == "npc"
                  npc_id = path.split(".")[1]
                  world.dig("npcs", npc_id, "dialogue", "topics", value).is_a?(Hash)
                else
                  (world["npcs"] || {}).values.any? do |n|
                    n.is_a?(Hash) && n.dig("dialogue", "topics", value).is_a?(Hash)
                  end
                end
        return nil if found

        { code: "topic.missing", path: path,
          message: "#{path} names dialogue topic '#{value}', which no matching NPC defines." }
      end

      # Walks a dotted path with * wildcards, yielding [dotted_path, value] for
      # every value the path reaches.
      def each_at(node, segments, trail, &)
        if segments.empty?
          yield trail.join("."), node
          return
        end

        seg = segments.first
        rest = segments.drop(1)
        if seg == "*"
          case node
          when Hash then node.each { |k, v| each_at(v, rest, trail + [k], &) }
          when Array then node.each_with_index { |v, i| each_at(v, rest, trail + [i.to_s], &) }
          end
        elsif node.is_a?(Hash) && node.key?(seg)
          each_at(node[seg], rest, trail + [seg], &)
        end
      end
  end
end
