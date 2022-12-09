# frozen_string_literal: true

class MessageComponent < ViewComponent::Base
  def initialize(message:, current_user:)
    @message = message
    @user = current_user
  end

  def container_classes
    classes(
      "text-bold": !@message.player_message? && @message.game_user&.user == @user,
      "text-white host-message py-2 pl-5": @message.host_message? && !@message.event?
    )
  end
end
