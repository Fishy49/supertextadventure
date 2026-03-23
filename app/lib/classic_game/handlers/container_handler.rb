# frozen_string_literal: true

module ClassicGame
  module Handlers
    class ContainerHandler < BaseHandler
      def handle(command)
        case command[:verb]
        when :open
          handle_open(command[:target])
        when :close
          handle_close(command[:target])
        else
          failure("I don't understand that command.")
        end
      end

      private

        def handle_open(target)
          return failure("Open what?") unless target

          # Find the container
          container_id, container_def = find_item(target)
          return failure("You don't see that here.") unless container_def

          # Check if it's accessible (in room or inventory)
          return failure("You don't see that here.") unless item_accessible?(container_id)

          # Check if it's a container
          return failure("You can't open that.") unless container_def["is_container"]

          # Check if it's already open
          return failure("It's already open.") if game.container_open?(container_id)

          # Check if it's locked
          if container_def["locked"]
            unlock_item = container_def["unlock_item"]
            if unlock_item && item?(unlock_item)
              # Player has the key, unlock and open
              game.open_container(container_id)
              message = container_def["on_open_message"] || "You unlock and open the #{container_def['name']}."
              return success(message)
            else
              locked_msg = container_def["locked_message"] || "It's locked."
              return failure(locked_msg)
            end
          end

          # Open the container
          game.open_container(container_id)
          message = container_def["on_open_message"] || "You open the #{container_def['name']}."

          # Show contents if any
          contents = game.container_contents(container_id)
          if contents.any?
            content_names = contents.map { |item_id| world_snapshot.dig("items", item_id, "name") || item_id }
            message += "\n\nInside you see: #{content_names.join(', ')}"
          end

          success(message)
        end

        def handle_close(target)
          return failure("Close what?") unless target

          # Find the container
          container_id, container_def = find_item(target)
          return failure("You don't see that here.") unless container_def

          # Check if it's accessible (in room or inventory)
          return failure("You don't see that here.") unless item_accessible?(container_id)

          # Check if it's a container
          return failure("You can't close that.") unless container_def["is_container"]

          # Check if it's already closed
          return failure("It's already closed.") unless game.container_open?(container_id)

          # Close the container
          game.close_container(container_id)
          message = container_def["on_close_message"] || "You close the #{container_def['name']}."

          success(message)
        end

        # Check if item is accessible (in room or inventory)
        def item_accessible?(item_id)
          item_in_room?(item_id) || item?(item_id) || item_in_open_container?(item_id)
        end

        # Check if item is in an open container that's accessible
        def item_in_open_container?(item_id)
          # Check all items in room and inventory for containers
          accessible_items = (current_room_state["items"] || []) + (player_state["inventory"] || [])

          accessible_items.each do |potential_container_id|
            container_def = world_snapshot.dig("items", potential_container_id)
            next unless container_def&.dig("is_container")
            next unless game.container_open?(potential_container_id)

            contents = game.container_contents(potential_container_id)
            return true if contents.include?(item_id)

            # Recursively check nested containers
            contents.each do |nested_item_id|
              nested_def = world_snapshot.dig("items", nested_item_id)
              if nested_def&.dig("is_container") && game.container_open?(nested_item_id)
                nested_contents = game.container_contents(nested_item_id)
                return true if nested_contents.include?(item_id)
              end
            end
          end

          false
        end
    end
  end
end
