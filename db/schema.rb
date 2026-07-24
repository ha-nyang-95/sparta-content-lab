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

ActiveRecord::Schema[8.1].define(version: 2026_07_24_100003) do
  create_table "channels", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.boolean "excluded", default: false, null: false
    t.string "handle"
    t.string "name", null: false
    t.string "source", null: false
    t.integer "subscriber_count"
    t.datetime "updated_at", null: false
    t.string "uploads_playlist_id"
    t.string "youtube_channel_id"
    t.index ["handle"], name: "index_channels_on_handle_not_null", unique: true, where: "handle IS NOT NULL"
    t.index ["youtube_channel_id"], name: "index_channels_on_youtube_channel_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.integer "comment_count"
    t.datetime "created_at", null: false
    t.integer "duration"
    t.boolean "is_short"
    t.integer "like_count"
    t.datetime "published_at"
    t.string "thumbnail"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "view_count"
    t.string "youtube_video_id", null: false
    t.index ["channel_id"], name: "index_videos_on_channel_id"
    t.index ["youtube_video_id"], name: "index_videos_on_youtube_video_id", unique: true
  end

  add_foreign_key "sessions", "users"
  add_foreign_key "videos", "channels"
end
