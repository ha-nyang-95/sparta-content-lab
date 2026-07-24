# 추적 대상 채널 테이블 — youtube_channel_id는 시드 미해결분 위해 nullable·유니크(다중 NULL 허용)
class CreateChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :channels do |t|
      t.string :youtube_channel_id
      t.string :handle
      t.string :name, null: false
      t.string :category, null: false
      t.string :source, null: false
      t.boolean :excluded, null: false, default: false
      t.integer :subscriber_count
      t.string :uploads_playlist_id

      t.timestamps
    end
    # SQLite 유니크 인덱스는 NULL을 서로 다르게 취급 — 미해결 시드의 다중 NULL 허용
    add_index :channels, :youtube_channel_id, unique: true
  end
end
