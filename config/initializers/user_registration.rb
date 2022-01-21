# frozen_string_literal: true

class UserRegistration
  def self.allowed?
    ENV.fetch("ALLOW_USER_REGISTRATION", "true") == "true"
  end
end
