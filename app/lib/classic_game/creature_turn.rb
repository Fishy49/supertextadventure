# frozen_string_literal: true

module ClassicGame
  # A creature's combat turn. Picks a live in-combat player, deals damage
  # (respecting defender bonus), handles target death, and ends combat if
  # no valid targets remain. Returns two narrations for the engine:
  #   :actor     - second person when the acting player is the target
  #   :spectator - character names only, safe to show other players
  class CreatureTurn
    class << self
      def run(game, creature_id, acting_user_id: nil)
        creature_def = game.world_snapshot.dig("creatures", creature_id) || {}
        combat = game.combat_state
        return empty_turn unless combat

        targets = live_targets(game, combat["room_id"])
        if targets.empty?
          ClassicGame::TurnManager.exit_combat_mode(game)
          return empty_turn
        end

        target_uid, target_ps = targets.to_a.sample
        apply_attack(game, creature_def, target_uid, target_ps, acting_user_id)
      end

      private

        def empty_turn
          { actor: "", spectator: "" }
        end

        def live_targets(game, room_id)
          game.players_in_room(room_id).select { |_, ps| ps.dig("combat", "active") }
        end

        def apply_attack(game, creature_def, target_uid, target_ps, acting_user_id)
          viewer_is_target = acting_user_id && target_uid.to_i == acting_user_id.to_i
          target_name = game.character_name_for(target_uid) || "Player #{target_uid}"

          defending = target_ps.dig("combat", "defending") ? true : false
          damage = calculate_damage(creature_def, target_ps, defending: defending, world: game.world_snapshot)

          max_health = target_ps["max_health"] || 10
          new_health = [(target_ps["health"] || 10) - damage, 0].max
          persist_hit(game, target_uid, target_ps, new_health)

          hit = { damage: damage, defending: defending, new_health: new_health, max_health: max_health }
          actor_lines = narration_lines(
            creature_def, viewer_is_target ? "you" : target_name, hit, second_person: viewer_is_target
          )
          spectator_lines = narration_lines(creature_def, target_name, hit, second_person: false)

          if new_health <= 0
            actor_lines << "" << restart_hint if viewer_is_target && solo_game?(game)
            handle_death(game, target_uid, target_ps)
          end

          { actor: actor_lines.join("\n"), spectator: spectator_lines.join("\n") }
        end

        # hit: { damage:, defending:, new_health:, max_health: }
        def narration_lines(creature_def, target_name, hit, second_person:)
          possessive = second_person ? "Your" : "#{target_name}'s"
          lines = []
          lines << strike_line(creature_def, target_name, hit[:damage], hit[:defending], second_person)
          lines << "#{possessive} health: #{hit[:new_health]}/#{hit[:max_health]}"
          if hit[:new_health] <= 0
            lines << ""
            lines << "#{second_person ? 'You have' : "#{target_name} has"} been defeated!"
          end
          lines
        end

        def strike_line(creature_def, target_name, damage, defending, second_person)
          if defending
            blocker = second_person ? "you block" : "they block"
            "The #{creature_def['name']} strikes at #{target_name}, but #{blocker} most of the blow!"
          else
            "The #{creature_def['name']} attacks #{target_name} for #{damage} damage!"
          end
        end

        def restart_hint
          "Type RESTART to try again."
        end

        def solo_game?(game)
          game.all_player_user_ids.length <= 1
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
