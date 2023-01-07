# frozen_string_literal: true

class SetupToken < ApplicationRecord
  belongs_to :user, optional: true

  before_create :set_uuid

  scope :active, -> { where(user_id: nil) }

  def active?
    user_id.nil?
  end

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
    end
end
