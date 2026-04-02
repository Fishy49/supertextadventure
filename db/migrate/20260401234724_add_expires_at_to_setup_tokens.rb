# frozen_string_literal: true

class AddExpiresAtToSetupTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :setup_tokens, :expires_at, :datetime
  end
end
