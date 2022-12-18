# frozen_string_literal: true

class EventMessageComponent < ViewComponent::Base
  def initialize(message)
    super

    @message = message
  end
end
