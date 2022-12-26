# frozen_string_literal: true

class NoticeComponent < ViewComponent::Base
  def initialize(message: nil, level: :info)
    super

    @message = message
    @level = level
  end

  def render?
    @message.present?
  end
end
