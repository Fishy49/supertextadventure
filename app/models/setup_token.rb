# frozen_string_literal: true

class SetupToken < ApplicationRecord
  belongs_to :user, optional: true

  before_create :set_uuid

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
    end
end
