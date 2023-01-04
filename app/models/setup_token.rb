# frozen_string_literal: true

class SetupToken < ApplicationRecord
  belongs_to :user, optional: true
end
