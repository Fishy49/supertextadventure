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

ActiveRecord::Schema.define(version: 2021_07_25_060931) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

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

  add_foreign_key "characters", "users"
  add_foreign_key "games", "users"
  add_foreign_key "standard_stat_sheets", "characters"
end
