# frozen_string_literal: true

# Table for Solid Cable (database-backed Action Cable adapter), installed into
# the primary database rather than a separate cable database.
# Mirrors db/cable_schema.rb from solid_cable 4.0.2.
class CreateSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false
      t.index [:channel], name: "index_solid_cable_messages_on_channel"
      t.index [:channel_hash], name: "index_solid_cable_messages_on_channel_hash"
      t.index [:created_at], name: "index_solid_cable_messages_on_created_at"
    end
  end
end
