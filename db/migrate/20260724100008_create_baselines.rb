# 채널·유형(쇼츠/롱폼)별 중앙값 기준선을 물질화하는 baselines 테이블 생성 — (channel, video_type) 유니크(AD-5)
class CreateBaselines < ActiveRecord::Migration[8.1]
  def change
    create_table :baselines do |t|
      t.references :channel, null: false, foreign_key: true, index: true
      t.string :video_type, null: false
      t.float :median_view_count
      t.integer :sample_size, null: false, default: 0
      t.boolean :low_confidence, null: false, default: true

      t.timestamps
    end

    add_index :baselines, [:channel_id, :video_type], unique: true
  end
end
