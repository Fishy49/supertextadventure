# frozen_string_literal: true

json.array! @friend_requests, partial: "friend_requests/friend_request", as: :friend_request
