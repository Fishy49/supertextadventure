# frozen_string_literal: true

class Chapter < ApplicationRecord
  belongs_to :game
  belongs_to :first_message, class_name: "Message", optional: true
  belongs_to :last_message, class_name: "Message", optional: true

  def all_messages
    Message.where(game_id: game.id)
           .where("id >= ?", first_message.id)
           .where("id <= ?", last_message.id)
           .order(id: :asc)
  end
end
