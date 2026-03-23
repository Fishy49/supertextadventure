# frozen_string_literal: true

class JsonDiff
  def self.diff(old_obj, new_obj, path = [])
    changes = []

    # Handle nil cases
    return changes if old_obj == new_obj
    return [[path_string(path), "added", nil, new_obj]] if old_obj.nil?
    return [[path_string(path), "removed", old_obj, nil]] if new_obj.nil?

    # Different types
    return [[path_string(path), "changed", old_obj, new_obj]] if old_obj.class != new_obj.class

    # Hash comparison
    if old_obj.is_a?(Hash) && new_obj.is_a?(Hash)
      all_keys = (old_obj.keys + new_obj.keys).uniq

      all_keys.each do |key|
        if !old_obj.key?(key)
          changes << [path_string(path + [key]), "added", nil, new_obj[key]]
        elsif !new_obj.key?(key)
          changes << [path_string(path + [key]), "removed", old_obj[key], nil]
        else
          changes.concat(diff(old_obj[key], new_obj[key], path + [key]))
        end
      end

      return changes
    end

    # Array comparison
    if old_obj.is_a?(Array) && new_obj.is_a?(Array)
      max_length = [old_obj.length, new_obj.length].max

      (0...max_length).each do |i|
        if i >= old_obj.length
          changes << [path_string(path + ["[#{i}]"]), "added", nil, new_obj[i]]
        elsif i >= new_obj.length
          changes << [path_string(path + ["[#{i}]"]), "removed", old_obj[i], nil]
        else
          changes.concat(diff(old_obj[i], new_obj[i], path + ["[#{i}]"]))
        end
      end

      return changes
    end

    # Primitive comparison
    changes << [path_string(path), "changed", old_obj, new_obj] if old_obj != new_obj

    changes
  end

  def self.format_changes(changes, new_obj = nil)
    return "  No changes" if changes.empty?

    output = []

    # Group changes by their parent path
    grouped_changes = changes.group_by do |path, _action, _old_val, _new_val|
      # Get the parent path (e.g., "room_states.library" from "room_states.library.items")
      parts = path.split(".")
      parts.length > 1 ? parts[0..-2].join(".") : nil
    end

    grouped_changes.each do |parent_path, group|
      group.each do |path, action, old_val, new_val|
        case action
        when "added"
          output << "  + #{path}: #{format_value(new_val)}"
        when "removed"
          output << "  - #{path}: #{format_value(old_val)}"
        when "changed"
          output << "  ~ #{path}:"
          output << "      old: #{format_value(old_val)}"
          output << "      new: #{format_value(new_val)}"
        end
      end

      # Show final state of parent if available and there are nested changes
      next unless parent_path && new_obj

      parent_value = dig_path(new_obj, parent_path)
      next unless parent_value.is_a?(Hash) || parent_value.is_a?(Array)

      output << ""
      output << "  Final state of #{parent_path}:"
      output << indent_json(parent_value, 4)
      output << ""
    end

    output.join("\n")
  end

  def self.dig_path(obj, path_string)
    parts = path_string.split(".")
    parts.reduce(obj) do |current, part|
      current.is_a?(Hash) ? current[part] : nil
    end
  end

  def self.indent_json(value, indent_level)
    JSON.pretty_generate(value).lines.map { |line| (" " * indent_level) + line.chomp }.join("\n")
  end

  def self.path_string(path)
    return "(root)" if path.empty?

    path.map { |p| p.to_s.start_with?("[") ? p : ".#{p}" }.join.sub(/^\./, "")
  end

  def self.format_value(value)
    case value
    when Hash, Array
      JSON.generate(value)
    when String
      "\"#{value}\""
    when nil
      "null"
    else
      value.to_s
    end
  end
end
