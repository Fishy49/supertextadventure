# frozen_string_literal: true

module ClassicGame
  # A creature's combat turn. Picks a live in-combat player, deals damage
  # (respecting defender bonus), handles target death, and ends combat if
  # no valid targets remain. Returns a multi-line text response for the
  # engine to append to the acting player's output.
  class CreatureTurn
    class << self
      def run(game, creature_id, acting_user_id: nil)
        creature_def = game.world_snapshot.dig("creatures", creature_id) || {}
        combat = game.combat_state
        return "" unless combat

        targets = live_targets(game, combat["room_id"])
        if targets.empty?
          ClassicGame::TurnManager.exit_combat_mode(game)
          return ""
        end

        target_uid, target_ps = targets.to_a.sample
        apply_attack(game, creature_def, target_uid, target_ps, acting_user_id)
      end

      private

        def live_targets(game, room_id)
          game.players_in_room(room_id).select { |_, ps| ps.dig("combat", "active") }
        end

        def apply_attack(game, creature_def, target_uid, target_ps, acting_user_id)
          viewer_is_target = acting_user_id && target_uid.to_i == acting_user_id.to_i
          target_name = viewer_is_target ? "you" : (game.character_name_for(target_uid) || "Player #{target_uid}")
          possessive = viewer_is_target ? "your" : "#{target_name}'s"

          defending = target_ps.dig("combat", "defending") ? true : false
          damage = calculate_damage(creature_def, target_ps, defending: defending, world: game.world_snapshot)

          max_health = target_ps["max_health"] || 10
          new_health = [(target_ps["health"] || 10) - damage, 0].max
          persist_hit(game, target_uid, target_ps, new_health)

          lines = []
          lines << strike_line(creature_def, target_name, damage, defending, viewer_is_target)
          lines << "#{possessive.capitalize} health: #{new_health}/#{max_health}"
          if new_health <= 0
            lines << ""
            lines << "#{viewer_is_target ? 'You have' : "#{target_name} has"} been defeated!"
            handle_death(game, target_uid, target_ps)
          end
          lines.join("\n")
        end

        def strike_line(creature_def, target_name, damage, defending, viewer_is_target)
          if defending
            blocker = viewer_is_target ? "you block" : "they block"
            "The #{creature_def['name']} strikes at #{target_name}, but #{blocker} most of the blow!"
          else
            "The #{creature_def['name']} attacks #{target_name} for #{damage} damage!"
          end
        end

        def persist_hit(game, target_uid, target_ps, new_health)
          new_ps = target_ps.dup
          new_ps["health"] = new_health
          new_ps["combat"] = new_ps["combat"].merge("defending" => false) if new_ps["combat"]
          game.update_player_state(target_uid, new_ps)
        end

        def handle_death(game, target_uid, target_ps)
          dead_ps = target_ps.dup
          dead_ps["combat"] = nil
          dead_ps["pending_restart"] = true
          game.update_player_state(target_uid, dead_ps)
          ClassicGame::TurnManager.remove_from_combat(game, target_uid)
        end

        def calculate_damage(creature_def, target_ps, defending:, world:)
          creature_attack = creature_def["attack"] || 5
          randomness = rand(-2..2)
          player_defense = (target_ps["inventory"] || []).sum do |item_id|
            world.dig("items", item_id, "defense_bonus") || 0
          end
          player_defense += 3 if defending

          [(creature_attack + randomness - player_defense), 1].max
        end
    end
  end
end
