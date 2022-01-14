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

ActiveRecord::Schema.define(version: 2022_01_12_053517) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "games", force: :cascade do |t|
    t.string "uuid"
    t.string "name"
    t.string "game_type"
    t.integer "created_by"
    t.string "status"
    t.datetime "opened_at", precision: 6
    t.datetime "closed_at", precision: 6
    t.boolean "is_friends_only"
    t.integer "max_players"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_games_on_name", unique: true
    t.index ["uuid"], name: "index_games_on_uuid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.citext "username"
    t.string "password_digest"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

end
