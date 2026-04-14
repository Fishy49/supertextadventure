# frozen_string_literal: true

class InventoryMessageComponent < ViewComponent::Base
  def initialize(message)
    super

    @message = message
  end

  def items
    @message.event_data || []
  end

  def item_count
    items.length
  end
end
