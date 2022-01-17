class GameUser < ApplicationRecord
  belongs_to :games, inverse_of: :game_users, dependent: :destroy
  belongs_to :users, inverse_of: :game_users, dependent: :destroy
end
