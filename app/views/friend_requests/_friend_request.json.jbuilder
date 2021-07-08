# frozen_string_literal: true

json.extract! friend_request, :id, :requester_id, :requestee_id, :status, :accepted_on, :rejected_on, :created_at,
              :updated_at
json.url friend_request_url(friend_request, format: :json)
