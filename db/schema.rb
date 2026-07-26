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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_213700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "images", force: :cascade do |t|
    t.string "caption"
    t.datetime "created_at", null: false
    t.string "filename"
    t.boolean "flagged", default: false, null: false
    t.datetime "flagged_at"
    t.datetime "last_scanned_at"
    t.jsonb "matched_terms", default: [], null: false
    t.jsonb "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["flagged"], name: "index_images_on_flagged"
    t.index ["last_scanned_at"], name: "index_images_on_last_scanned_at"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
