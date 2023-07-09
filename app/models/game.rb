# frozen_string_literal: true

class Game < ApplicationRecord
  CHATGPT_SYSTEM_PROMPT = <<-PROMPT.freeze
  You are now taking on the role of a Dungeon Master (DM) for a Dungeons & Dragons (D&D) game.
  As the DM, you will create a dynamic and engaging world, describe the environment,
  control non-player characters (NPCs),#{' '}
  and narrate the outcomes of players' actions.
  Your goal is to provide a fun and immersive experience, while ensuring that you follow the rules of the game and maintain a fair and balanced play environment.
  If a player asks to do something, ask them to make an appropriate ability with a dice roll.
  PROMPT

  MAX_TOKENS_FOR_AI_CHAPTER = 7000

  belongs_to :host, class_name: "User",
                    foreign_key: :created_by,
                    primary_key: :id,
                    dependent: :destroy,
                    inverse_of: :hosted_games,
                    optional: true

  has_many :game_users, inverse_of: :game, dependent: :destroy
  has_many :users, through: :game_users

  has_many :chapters, inverse_of: :game, dependent: :destroy

  has_many :messages, inverse_of: :game, dependent: :destroy

  scope :joinable_by_user, ->(user) { where(status: :open).where.not(created_by: user.id) }

  before_create :set_uuid

  after_save :broadcast_context, if: :saved_change_to_current_context?

  after_create_commit :setup_ai, if: proc { game_type == "chatgpt" }

  validates :created_by, presence: true

  def complete_chapters
    chapters.order(:id).where.not(last_message_id: nil)
  end

  def current_chapter
    chapters.where(last_message_id: nil).last
  end

  def current_messages
    messages.where("id > ?", current_chapter&.first_message_id || 0)
  end

  def current_token_count
    TOKENIZER.encode(messages_for_ai.select { |m| m[:content] }.join).tokens.count
  end

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

  def role_for_ai_message(message)
    role = "user" if message.player_message?
    role = "assistant" if message.host_message?
    role = "system" if message.is_system_message?
    role
  end

  def messages_for_ai
    chat_log_for_ai = [
      { role: "system", content: "#{CHATGPT_SYSTEM_PROMPT} The name of this D&D campaign is #{name}." }
    ]

    chat_log_for_ai += chapter_summaries

    current_messages.for_ai.each do |m|
      next if m.event?

      content = if m.player_message?
                  "[#{m.display_name}] #{m.content}"
                else
                  m.content
                end

      chat_log_for_ai << { role: role_for_ai_message(m), content: content }
    end
    chat_log_for_ai
  end

  def chapter_summaries
    summaries = []
    if complete_chapters.present?
      complete_chapters.each do |chapter|
        summaries << {
          role: "assistant", content: chapter.summary
        }
      end
    end
    summaries
  end

  def broadcast_updated_player_list
    broadcast_replace_to(self, :players, target: :players, partial: "/games/players",
                                         locals: { game_users: game_users.joined, for_host: false })
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
                    content: <<-INSTRUCTION
                    Please create a brief description of the game world. No players have joined yet.
                    Also describe the opening scene the players will once they join the game.
                    INSTRUCTION
                  }
      response = client.chat(parameters: { model: "gpt-4", messages: chat_log })
      ai_response = response.dig("choices", 0, "message", "content")

      message = Message.create(game_id: id, content: ai_response)

      Chapter.create(game_id: id, number: 1, first_message_id: message.id)
    end
end
