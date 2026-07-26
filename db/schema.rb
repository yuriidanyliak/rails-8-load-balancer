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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_100010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "backends", force: :cascade do |t|
    t.integer "active_connections", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "healthy", default: true, null: false
    t.string "host", null: false
    t.integer "times_selected", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 1, null: false
    t.index ["host"], name: "index_backends_on_host", unique: true
  end

  create_table "banned_words", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "phrase", null: false
    t.datetime "updated_at", null: false
    t.index "lower((phrase)::text)", name: "index_banned_words_on_lower_phrase", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.boolean "flagged", default: false, null: false
    t.datetime "flagged_at"
    t.datetime "last_scanned_at"
    t.jsonb "matched_terms", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["flagged"], name: "index_messages_on_flagged"
    t.index ["last_scanned_at"], name: "index_messages_on_last_scanned_at"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "done"
    t.string "title"
    t.datetime "updated_at", null: false
  end
end
