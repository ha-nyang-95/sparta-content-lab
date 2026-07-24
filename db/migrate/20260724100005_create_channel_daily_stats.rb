# 채널 구독자 일별 스냅샷 — 구독자 증감의 단일 원천(AD-5). (channel_id,date) 유니크로 하루 중복 차단
class CreateChannelDailyStats < ActiveRecord::Migration[8.1]
  def change
    create_table :channel_daily_stats do |t|
      t.references :channel, null: false, foreign_key: true, index: true
      t.date :date, null: false
      t.integer :subscriber_count

      t.timestamps
    end
    add_index :channel_daily_stats, [:channel_id, :date], unique: true
  end
end
