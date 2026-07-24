# 영상 메타 테이블 — 통계(view/like/comment)는 회원전용·누락 방어로 nullable(AD-9)
class CreateVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :videos do |t|
      t.string :youtube_video_id, null: false
      t.references :channel, null: false, foreign_key: true, index: true
      t.string :title
      t.boolean :is_short
      t.integer :view_count
      t.integer :duration
      t.datetime :published_at
      t.string :thumbnail
      t.integer :like_count
      t.integer :comment_count

      t.timestamps
    end
    add_index :videos, :youtube_video_id, unique: true
  end
end
