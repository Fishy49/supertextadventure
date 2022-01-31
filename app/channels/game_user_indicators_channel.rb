# frozen_string_literal: true

class GameUserIndicatorsChannel < ApplicationCable::Channel
  def subscribed
    GameUser.find(params[:id]).update(is_online: true)
  end

  def unsubscribed
    GameUser.find(params[:id]).update(is_online: false)
  end

  def typing(data)
    GameUser.find(data["game_user_id"]).update(is_typing: data["typing"])
  end
end
