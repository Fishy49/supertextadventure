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

ActiveRecord::Schema.define(version: 2021_09_27_034332) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "characters", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "race"
    t.string "height"
    t.string "hair_color"
    t.string "eye_color"
    t.text "backstory"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_characters_on_user_id"
  end

  create_table "friend_requests", force: :cascade do |t|
    t.integer "requester_id"
    t.integer "requestee_id"
    t.string "status"
    t.datetime "accepted_on"
    t.datetime "rejected_on"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "game_events", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.string "event_type"
    t.string "event_status"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_id"], name: "index_game_events_on_game_id"
  end

  create_table "game_messages", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "user_id", null: false
    t.bigint "game_event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_event_id"], name: "index_game_messages_on_game_event_id"
    t.index ["game_id"], name: "index_game_messages_on_game_id"
    t.index ["user_id"], name: "index_game_messages_on_user_id"
  end

  create_table "game_users", force: :cascade do |t|
    t.bigint "game_id"
    t.bigint "user_id"
    t.bigint "character_id"
    t.string "status"
    t.datetime "invited_at"
    t.datetime "joined_at"
    t.datetime "left_at"
    t.datetime "kicked_at"
    t.datetime "banned_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["character_id"], name: "index_game_users_on_character_id"
    t.index ["game_id", "user_id"], name: "index_game_users_on_game_id_and_user_id", unique: true
    t.index ["game_id"], name: "index_game_users_on_game_id"
    t.index ["user_id"], name: "index_game_users_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "game_type"
    t.string "status"
    t.text "description"
    t.boolean "is_friends_only"
    t.integer "max_players"
    t.datetime "opened_at"
    t.datetime "closed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_games_on_user_id"
  end

  create_table "standard_items", force: :cascade do |t|
    t.string "name"
    t.string "item_type"
    t.text "description"
    t.string "modifier_type"
    t.integer "modifier"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "standard_items_stat_sheets", id: false, force: :cascade do |t|
    t.bigint "standard_stat_sheet_id", null: false
    t.bigint "standard_item_id", null: false
  end

  create_table "standard_stat_sheets", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.integer "level"
    t.integer "xp"
    t.integer "max_hitpoints"
    t.integer "current_hitpoints"
    t.integer "max_spell_slots"
    t.integer "current_spell_slots"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["character_id"], name: "index_standard_stat_sheets_on_character_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "username"
    t.string "password_digest"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "characters", "users"
  add_foreign_key "game_events", "games"
  add_foreign_key "game_messages", "game_events"
  add_foreign_key "game_messages", "games"
  add_foreign_key "game_messages", "users"
  add_foreign_key "games", "users"
  add_foreign_key "standard_stat_sheets", "characters"
end
