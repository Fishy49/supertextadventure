# frozen_string_literal: true

# Shared combat state for classic multiplayer games: one source of truth
# for the creature's HP plus helpers to advance the combat turn order.
module CombatState
  extend ActiveSupport::Concern

  def in_combat?
    game_state["combat_state"].present?
  end

  def combat_state
    game_state["combat_state"]
  end

  def set_combat_state(room_id:, creature_id:, creature_health:)
    self.game_state ||= {}
    self.game_state["combat_state"] = {
      "room_id" => room_id.to_s,
      "creature_id" => creature_id.to_s,
      "creature_health" => creature_health,
      "creature_max_health" => creature_health
    }
    save!
  end

  def clear_combat_state
    self.game_state ||= {}
    self.game_state.delete("combat_state")
    save!
  end

  def update_creature_health(new_health)
    return unless in_combat?

    self.game_state["combat_state"] = combat_state.merge("creature_health" => new_health)
    save!
  end

  def current_combatant
    ts = turn_state
    order = ts["combat_turn_order"] || []
    return nil if order.empty?

    order[ts["combat_current_index"] || 0]
  end

  def current_combat_user_id
    c = current_combatant
    return nil unless c && c["type"] == "player"

    c["id"].to_i
  end

  def advance_combat_turn
    self.game_state ||= {}
    ts = turn_state.dup
    order = ts["combat_turn_order"] || []
    return nil if order.empty?

    current = ts["combat_current_index"] || 0
    current = (current + 1) % order.length
    ts["combat_current_index"] = current
    self.game_state["turn_state"] = ts
    save!
    order[current]
  end
end
