class User < ApplicationRecord
  has_many :created_games, class_name: 'Game', foreign_key: :created_by

  has_many :games_users, dependent: :nullify, join_table: :games_users, class_name: 'GamesUsers'
  has_many :games, through: :games_users

  has_many :users_friends, dependent: :nullify, join_table: :users_friends, class_name: 'UsersFriends'
  has_many :friends, through: :users_friends, source: :user

  has_many :sent_friend_requests, dependent: :nullify, class_name: 'FriendRequest'
  has_many :received_friend_requests, dependent: :nullify, class_name: 'FriendRequest', foreign_key: :friend_id

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attr_writer :login

  validate :validate_username

  def validate_username
    if User.where(email: username).exists?
      errors.add(:username, :invalid)
    end
  end

  def login
    @login || username || email
  end

  # rubocop:disable Rails/FindBy
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(['username = :value OR lower(email) = lower(:value)', { value: login }]).first
    elsif conditions.key?(:username) || conditions.key?(:email)
      where(conditions.to_h).first
    end
  end
  # rubocop:enable Rails/FindBy
end
