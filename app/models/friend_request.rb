# frozen_string_literal: true

class FriendRequest < ApplicationRecord
  has_one :requester, class_name: "User", foreign_key: :id, primary_key: :requester_id, dependent: :destroy,
                      inverse_of: :friend_requests
  has_one :requestee, class_name: "User", foreign_key: :id, primary_key: :requestee_id, dependent: :destroy,
                      inverse_of: :received_friend_requests

  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :rejected, -> { where(status: "rejected") }

  def pending?
    status == "pending"
  end

  def accepted?
    status == "accepted"
  end

  def rejected?
    status == "rejected"
  end
end
