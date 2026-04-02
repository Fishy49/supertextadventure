# frozen_string_literal: true

class SetupToken < ApplicationRecord
  belongs_to :user, optional: true

  before_create :set_uuid

  scope :active, -> { where(user_id: nil).where("expires_at > ?", Time.current) }

  def active?
    user_id.nil? && expires_at&.future?
  end

  private

    def set_uuid
      self.uuid = SecureRandom.uuid
      self.expires_at ||= 48.hours.from_now
    end
end
