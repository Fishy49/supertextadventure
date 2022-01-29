# frozen_string_literal: true

json.extract! inventory_item, :id, :game_user_id, :name, :quantity, :description, :ascii, :created_at, :updated_at
json.url inventory_item_url(inventory_item, format: :json)
