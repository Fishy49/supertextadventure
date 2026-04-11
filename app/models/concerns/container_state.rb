# frozen_string_literal: true

module ContainerState
  extend ActiveSupport::Concern

  def container_state(container_id)
    game_state.dig("container_states", container_id.to_s)
  end

  def container_open?(container_id)
    state = container_state(container_id)
    return state["open"] if state

    item_def = world_snapshot.dig("items", container_id.to_s)
    return true unless item_def&.dig("starts_closed")

    false
  end

  def open_container(container_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] = { "open" => true }
    save!
  end

  def close_container(container_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] = { "open" => false }
    save!
  end

  def container_contents(container_id)
    original_contents = world_snapshot.dig("items", container_id.to_s, "contents") || []
    removed_items = game_state.dig("container_states", container_id.to_s, "removed_items") || []
    original_contents - removed_items
  end

  def remove_from_container(container_id, item_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] ||= {}
    self.game_state["container_states"][container_id.to_s]["removed_items"] ||= []
    self.game_state["container_states"][container_id.to_s]["removed_items"] << item_id
    self.game_state["container_states"][container_id.to_s]["removed_items"].uniq!
    save!
  end

  def add_to_container(container_id, item_id)
    self.game_state ||= {}
    self.game_state["container_states"] ||= {}
    self.game_state["container_states"][container_id.to_s] ||= {}
    self.game_state["container_states"][container_id.to_s]["removed_items"] ||= []
    self.game_state["container_states"][container_id.to_s]["removed_items"].delete(item_id)
    save!
  end
end
