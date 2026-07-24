# 영상 조회수 일별 스냅샷 — 시계열 단일 원천(AD-5). (video_id,date) 유니크로 하루 중복 차단
class CreateVideoDailyStats < ActiveRecord::Migration[8.1]
  def change
    create_table :video_daily_stats do |t|
      t.references :video, null: false, foreign_key: true, index: true
      t.date :date, null: false
      t.integer :view_count

      t.timestamps
    end
    add_index :video_daily_stats, [:video_id, :date], unique: true
  end
end
