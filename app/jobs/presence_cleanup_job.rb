# frozen_string_literal: true

class PresenceCleanupJob < ApplicationJob
  queue_as :default

  def perform
    GameUser.typing.find_each do |gu|
      gu.update(is_typing: false) if (gu.typing_at + 10.seconds) < DateTime.now
    end

    GameUser.online.find_each do |gu|
      gu.update(is_online: false) if (gu.online_at + 10.seconds) < DateTime.now
    end

    Game.where(is_host_typing: true).find_each do |g|
      g.update(is_host_typing: false) if (g.host_typing_at + 10.seconds) < DateTime.now
    end

    Game.where(is_host_online: true).find_each do |g|
      g.update(is_host_online: false) if (g.host_online_at + 10.seconds) < DateTime.now
    end
  end
end
