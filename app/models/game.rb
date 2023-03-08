# frozen_string_literal: true

class Game < ApplicationRecord
  CHATGPT_SYSTEM_PROMPT = "You are a D&D game master. You will respond helpfully and creatively to user responses. You will always respond in the style of a D&D game master. All users will be players in the game. You will create the game world, scenery, characters, and descriptions."

  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    dependent: :destroy,
                    inverse_of: :hosted_games,
                    optional: true

  has_many :game_users, inverse_of: :game, dependent: :destroy
  has_many :users, through: :game_users

  has_many :messages, inverse_of: :game, dependent: :destroy

  scope :joinable_by_user, ->(user) { where(status: :open).where.not(created_by: user.id) }

  before_create :set_uuid

  after_save :broadcast_context, if: :saved_change_to_current_context?

  after_create_commit :setup_ai, if: proc { game_type == "chatgpt" }

  validates :created_by, presence: true

  def game_user(user)
    game_users.find_by(user_id: user.id)
  end

  def host?(user)
    return false if game_type == "chatgpt"

    created_by == user&.id
  end

  def user_in_game?(user)
    game_users.pluck(:user_id).include?(user.id)
  end

  def can_user_join?(user)
    !user_in_game?(user) && !host?(user) && !max_players?
  end

  def max_players?
    game_users.count == max_players
  end

  def messages_for_ai
    chat_log_for_ai = [
      { role: "system", content: "#{CHATGPT_SYSTEM_PROMPT} The name of this D&D campaign is #{name}." }
    ]

    messages.for_ai.each do |m|
      next if m.event?

      role = "user" if m.player_message?
      role = "assistant" if m.host_message?
      role = "system" if m.is_system_message?

      content = if m.player_message?
                  "The following message is from the player named \"#{m.display_name}\": #{m.content}"
                else
                  m.content
                end

      chat_log_for_ai << {
        role: role, content: content
      }
    end
    chat_log_for_ai
  end

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
    end

    def broadcast_context
      broadcast_replace_to(self, :state, target: :context_content, partial: "/games/current_context",
                                         locals: { game: self })
    end

    def setup_ai
      client = OpenAI::Client.new

      chat_log = messages_for_ai
      chat_log << { role: "user",
                    content: "Please create a brief description of the game world and describe the opening scene the players will see." }
      response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: chat_log
        }
      )
      ai_response = response.dig("choices", 0, "message", "content")

      Message.create(game_id: id, content: ai_response)
    end
end
