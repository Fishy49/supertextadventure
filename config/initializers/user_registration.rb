# frozen_string_literal: true

class UserRegistration
  def self.allowed?
    ENV.fetch("ALLOW_USER_REGISTRATION", "false") == "true"
  end
end
