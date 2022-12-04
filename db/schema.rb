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

ActiveRecord::Schema[7.0].define(version: 2022_12_04_055623) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "game_users", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "user_id", null: false
    t.string "character_name", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_health"
    t.integer "current_health"
    t.datetime "active_at"
    t.index ["game_id", "user_id"], name: "index_game_users_on_game_id_and_user_id", unique: true
    t.index ["game_id"], name: "index_game_users_on_game_id"
    t.index ["user_id"], name: "index_game_users_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "uuid"
    t.string "name"
    t.text "description"
    t.string "game_type"
    t.integer "created_by"
    t.string "status"
    t.string "host_display_name"
    t.datetime "opened_at"
    t.datetime "closed_at"
    t.boolean "is_friends_only"
    t.integer "max_players"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "current_context"
    t.boolean "is_current_context_ascii", default: false
    t.datetime "host_active_at"
    t.boolean "enable_hp", default: true
    t.integer "starting_hp", default: 10
    t.index ["name"], name: "index_games_on_name", unique: true
    t.index ["uuid"], name: "index_games_on_uuid", unique: true
  end

  create_table "inventory_items", force: :cascade do |t|
    t.bigint "game_user_id", null: false
    t.string "name"
    t.integer "quantity"
    t.text "description"
    t.text "ascii"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_user_id"], name: "index_inventory_items_on_game_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "game_user_id"
    t.string "sender_name"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_type"
    t.text "event_data"
    t.index ["game_id"], name: "index_messages_on_game_id"
    t.index ["game_user_id"], name: "index_messages_on_game_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "username"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "game_users", "games"
  add_foreign_key "game_users", "users"
  add_foreign_key "inventory_items", "game_users"
  add_foreign_key "messages", "games"
end
