# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_12_19_042007) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "character_items_tables", force: :cascade do |t|
    t.bigint "character_id"
    t.string "name"
    t.string "item_type"
    t.string "description"
    t.integer "damage"
    t.integer "healing"
    t.integer "armor"
    t.index ["character_id"], name: "index_character_items_tables_on_character_id"
  end

  create_table "characters", force: :cascade do |t|
    t.bigint "user_id"
    t.string "name"
    t.string "class"
    t.string "race"
    t.integer "level"
    t.integer "base_armor"
    t.integer "base_str"
    t.integer "base_dex"
    t.integer "base_con"
    t.integer "base_int"
    t.integer "base_wis"
    t.integer "base_cha"
    t.integer "max_hp"
    t.integer "current_hp"
    t.integer "temporary_hp"
    t.index ["user_id"], name: "index_characters_on_user_id"
  end

  create_table "characters_games", id: false, force: :cascade do |t|
    t.bigint "character_id", null: false
    t.bigint "game_id", null: false
  end

  create_table "friend_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "friend_id"
    t.boolean "is_accepted"
    t.boolean "is_rejected"
    t.datetime "responded_at"
    t.string "message", default: ""
    t.string "timestamps"
    t.index ["friend_id"], name: "index_friend_requests_on_friend_id"
    t.index ["user_id"], name: "index_friend_requests_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "name"
    t.string "mode"
    t.string "description", default: ""
    t.integer "max_players"
    t.string "timestamps"
  end

  create_table "games_users", id: false, force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "user_id", null: false
    t.string "role"
    t.index ["game_id", "user_id"], name: "index_games_users_on_game_id_and_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "username"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "users_friends", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "friend_id"
    t.boolean "is_accepted"
    t.boolean "is_rejected"
    t.datetime "responded_at"
    t.string "message", default: ""
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id", "friend_id"], name: "index_users_friends_on_user_id_and_friend_id"
    t.index ["user_id"], name: "index_users_friends_on_user_id"
  end

end
