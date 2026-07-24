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

ActiveRecord::Schema[8.1].define(version: 2026_07_24_100016) do
  create_table "baselines", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.datetime "created_at", null: false
    t.boolean "low_confidence", default: true, null: false
    t.float "median_view_count"
    t.integer "sample_size", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "video_type", null: false
    t.index ["channel_id", "video_type"], name: "index_baselines_on_channel_id_and_video_type", unique: true
    t.index ["channel_id"], name: "index_baselines_on_channel_id"
  end

  create_table "channel_daily_stats", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "subscriber_count"
    t.datetime "updated_at", null: false
    t.index ["channel_id", "date"], name: "index_channel_daily_stats_on_channel_id_and_date", unique: true
    t.index ["channel_id"], name: "index_channel_daily_stats_on_channel_id"
  end

  create_table "channels", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.boolean "excluded", default: false, null: false
    t.string "handle"
    t.boolean "is_own", default: false, null: false
    t.string "name", null: false
    t.string "source", null: false
    t.integer "subscriber_count"
    t.datetime "updated_at", null: false
    t.string "uploads_playlist_id"
    t.string "youtube_channel_id"
    t.index ["handle"], name: "index_channels_on_handle_not_null", unique: true, where: "handle IS NOT NULL"
    t.index ["youtube_channel_id"], name: "index_channels_on_youtube_channel_id", unique: true
  end

  create_table "job_runs", force: :cascade do |t|
    t.integer "channels_failed", default: 0, null: false
    t.integer "channels_processed", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "error"
    t.datetime "finished_at"
    t.string "job_name", null: false
    t.integer "quota_used"
    t.integer "retries", default: 0, null: false
    t.datetime "started_at"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["job_name", "created_at"], name: "index_job_runs_on_job_name_and_created_at"
  end

  create_table "own_video_matches", force: :cascade do |t|
    t.integer "competitor_video_id", null: false
    t.datetime "created_at", null: false
    t.integer "own_video_id", null: false
    t.float "similarity", null: false
    t.datetime "updated_at", null: false
    t.index ["competitor_video_id", "own_video_id"], name: "idx_on_competitor_video_id_own_video_id_4c98b9fe5a", unique: true
    t.index ["competitor_video_id"], name: "index_own_video_matches_on_competitor_video_id"
    t.index ["own_video_id"], name: "index_own_video_matches_on_own_video_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "topic_clusters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "size"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "video_daily_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.datetime "updated_at", null: false
    t.integer "video_id", null: false
    t.integer "view_count"
    t.index ["video_id", "date"], name: "index_video_daily_stats_on_video_id_and_date", unique: true
    t.index ["video_id"], name: "index_video_daily_stats_on_video_id"
  end

  create_table "video_scores", force: :cascade do |t|
    t.string "content_gap_bucket"
    t.datetime "created_at", null: false
    t.boolean "evergreen_candidate", default: false, null: false
    t.boolean "needs_verification", default: false, null: false
    t.integer "own_match_count"
    t.float "performance_multiple"
    t.boolean "rank_eligible", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "video_id", null: false
    t.index ["video_id"], name: "index_video_scores_on_video_id", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.integer "comment_count"
    t.datetime "created_at", null: false
    t.integer "duration"
    t.binary "embedding"
    t.string "embedding_source_hash"
    t.boolean "is_short"
    t.integer "like_count"
    t.datetime "published_at"
    t.string "thumbnail"
    t.string "title"
    t.integer "topic_cluster_id"
    t.datetime "updated_at", null: false
    t.integer "view_count"
    t.string "youtube_video_id", null: false
    t.index ["channel_id"], name: "index_videos_on_channel_id"
    t.index ["topic_cluster_id"], name: "index_videos_on_topic_cluster_id"
    t.index ["youtube_video_id"], name: "index_videos_on_youtube_video_id", unique: true
  end

  add_foreign_key "baselines", "channels"
  add_foreign_key "channel_daily_stats", "channels"
  add_foreign_key "own_video_matches", "videos", column: "competitor_video_id"
  add_foreign_key "own_video_matches", "videos", column: "own_video_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "video_daily_stats", "videos"
  add_foreign_key "video_scores", "videos"
  add_foreign_key "videos", "channels"
  add_foreign_key "videos", "topic_clusters"
end
