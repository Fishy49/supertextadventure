# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_01_234724) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "game_users", force: :cascade do |t|
    t.datetime "active_at"
    t.boolean "can_message", default: true
    t.text "character_description"
    t.string "character_name", null: false
    t.datetime "created_at", null: false
    t.integer "current_health"
    t.bigint "game_id", null: false
    t.boolean "is_active", default: true
    t.integer "max_health"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["game_id", "user_id"], name: "index_game_users_on_game_id_and_user_id", unique: true
    t.index ["game_id"], name: "index_game_users_on_game_id"
    t.index ["user_id"], name: "index_game_users_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.integer "created_by"
    t.text "current_context"
    t.text "description"
    t.boolean "enable_hp", default: true
    t.jsonb "game_state", default: {}, null: false
    t.string "game_type"
    t.datetime "host_active_at"
    t.string "host_display_name"
    t.boolean "is_current_context_ascii", default: false
    t.boolean "is_friends_only"
    t.integer "max_players"
    t.string "name"
    t.datetime "opened_at"
    t.integer "starting_hp", default: 10
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.bigint "world_id"
    t.index ["name"], name: "index_games_on_name", unique: true
    t.index ["uuid"], name: "index_games_on_uuid", unique: true
    t.index ["world_id"], name: "index_games_on_world_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.text "event_data"
    t.string "event_type"
    t.bigint "game_id", null: false
    t.bigint "game_user_id"
    t.boolean "is_system_message", default: false
    t.string "sender_name"
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_messages_on_game_id"
    t.index ["game_user_id"], name: "index_messages_on_game_user_id"
  end

  create_table "setup_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "uuid"
    t.index ["user_id"], name: "index_setup_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_owner", default: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.citext "username"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "worlds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
    t.jsonb "world_data"
  end

  add_foreign_key "game_users", "games"
  add_foreign_key "game_users", "users"
  add_foreign_key "games", "worlds"
  add_foreign_key "messages", "games"
end
