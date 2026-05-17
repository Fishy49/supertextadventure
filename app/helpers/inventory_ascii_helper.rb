# frozen_string_literal: true

module InventoryAsciiHelper
  RECOGNISED_CATEGORIES = %w[weapon shield armor key potion scroll gem crown book ring food container torch generic].freeze

  def inventory_category_for(item_def)
    explicit = item_def["category"]
    return explicit if explicit && RECOGNISED_CATEGORIES.include?(explicit)

    return "container" if item_def["is_container"]
    return "weapon"    if item_def["weapon_damage"].to_i > 0
    return "armor"     if item_def["defense_bonus"].to_i > 0
    return "potion"    if item_def.dig("combat_effect", "type") == "heal"
    return "scroll"    if item_def.dig("on_use", "type") == "message"
    return "key"       if item_def.dig("on_use", "type") == "unlock"

    "generic"
  end

  def inventory_ascii_for(item_def)
    return item_def["ascii_art"] if item_def["ascii_art"].present?

    category = inventory_category_for(item_def)
    partial_name = category_to_partial(category)

    safe_render_ascii(partial_name) || safe_render_ascii("generic") || ""
  end

  private

    def category_to_partial(category)
      case category
      when "weapon" then "sword"
      else category
      end
    end

    # Render an ASCII partial, swallowing any errors so a malformed or missing
    # template never aborts the surrounding inventory partial render — that
    # render is invoked from `broadcast_replace_to`, where a raise causes the
    # broadcast to be dropped silently and the sidebar stays out of sync.
    def safe_render_ascii(partial_name)
      render("ascii/items/#{partial_name}")
    rescue StandardError
      nil
    end
end
