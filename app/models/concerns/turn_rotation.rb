# frozen_string_literal: true

# The classic-game turn rotation: who is in the order, whose turn it is,
# and the host-facing surgery (reorder, bench, unbench) on that order.
module TurnRotation
  extend ActiveSupport::Concern

  def turn_state
    game_state["turn_state"] || { "turn_order" => [], "current_index" => 0 }
  end

  def current_turn_user_id
    ts = turn_state
    order = ts["turn_order"] || []
    return nil if order.empty?

    order[ts["current_index"] || 0]
  end

  def advance_turn
    self.game_state ||= {}
    ts = turn_state.dup
    order = ts["turn_order"] || []
    return nil if order.empty?

    count = order.length
    current = ts["current_index"] || 0

    attempts = 0
    loop do
      current = (current + 1) % count
      attempts += 1
      break if attempts >= count

      uid = order[current]
      next_ps = game_state.dig("player_states", uid.to_s) || {}
      break unless next_ps["waiting_for_combat_end"]
    end

    ts["current_index"] = current
    game_state["turn_state"] = ts
    save!
    order[current]
  end

  def register_player_turn_order(user_id)
    self.game_state ||= {}
    game_state["turn_state"] ||= { "turn_order" => [], "current_index" => 0 }
    order = game_state["turn_state"]["turn_order"] ||= []
    order << user_id.to_i unless order.include?(user_id.to_i)
  end

  # Players with a state in this game who are not in the rotation (host-benched
  # or auto-removed). They can watch but not act until re-added.
  def benched_user_ids
    all_player_user_ids - (turn_state["turn_order"] || [])
  end

  # Replace the rotation with a new ordering of the same players, keeping the
  # cursor on the current player when possible.
  def reorder_turns(user_ids)
    ts = turn_state.dup
    current_uid = current_turn_user_id
    ts["turn_order"] = user_ids.map(&:to_i)
    ts["current_index"] = ts["turn_order"].index(current_uid) || 0
    game_state["turn_state"] = ts
    save!
  end

  def remove_from_turn_order(user_id)
    ts = turn_state.dup
    order = (ts["turn_order"] || []).dup
    idx = order.index(user_id.to_i)
    return unless idx

    current = ts["current_index"] || 0
    order.delete_at(idx)
    if order.empty?
      current = 0
    else
      # Removing an earlier entry shifts everything left; removing the current
      # entry leaves the cursor on whoever slid into the slot.
      current -= 1 if idx < current
      current %= order.length
    end
    ts["turn_order"] = order
    ts["current_index"] = current
    game_state["turn_state"] = ts
    save!
  end

  def add_to_turn_order(user_id)
    ts = turn_state.dup
    order = (ts["turn_order"] || []).dup
    return if order.include?(user_id.to_i)

    order << user_id.to_i
    ts["turn_order"] = order
    game_state["turn_state"] = ts
    save!
  end
end
