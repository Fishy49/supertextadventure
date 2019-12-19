class GamesUsers < ApplicationRecord
  has_many :games, dependent: :nullify
  has_many :users, dependent: :nullify
end
