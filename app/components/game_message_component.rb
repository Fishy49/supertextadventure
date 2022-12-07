# frozen_string_literal: true

class GameMessageComponent < ViewComponent::Base
  def initialize(message:, current_user:)
    @message = message
    @current_user = current_user
  end

end
