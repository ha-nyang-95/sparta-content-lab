# 사용자별 영상 저장(북마크) — (user, video) 유니크, app(primary) DB
class CreateSavedVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_videos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :video, null: false, foreign_key: true
      t.timestamps
    end
    add_index :saved_videos, [:user_id, :video_id], unique: true
  end
end
