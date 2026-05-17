# frozen_string_literal: true

module InventoryArtHelper
  KEYWORD_TO_PARTIAL = {
    %w[sword blade]            => "inv_sword",
    %w[key]                    => "inv_key",
    %w[potion flask elixir]    => "inv_potion",
    %w[scroll parchment tome]  => "inv_scroll",
    %w[gem crystal stone]      => "inv_gem",
    %w[crown diadem circlet]   => "inv_crown",
    %w[chest crate box coffer] => "inv_chest",
    %w[lockpick pick]          => "inv_lockpick"
  }.freeze

  def inventory_art_partial_for(item_id, item_def)
    override = item_def.is_a?(Hash) ? item_def["ascii_art_partial"] : nil
    return override if override.is_a?(String) && override.match?(/\A[a-z0-9_]+\z/)

    keywords = (item_def.is_a?(Hash) ? Array(item_def["keywords"]) : [])
    tokens = (keywords + [item_id.to_s]).map(&:downcase)

    KEYWORD_TO_PARTIAL.each do |keys, partial|
      return partial if tokens.any? { |t| keys.include?(t) }
    end

    "inv_generic"
  end

  def inventory_art(item_id, item_def)
    ascii(inventory_art_partial_for(item_id, item_def))
  end
end
