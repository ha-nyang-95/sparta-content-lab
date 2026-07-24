# 추천 주제 스냅샷 테이블 — 휘발 TopicCluster에 FK 없이 생성 시점 값을 자체 보존(AD-10)
class CreateRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendations do |t|
      t.text :reference_video_ids
      t.string :topic_label
      t.float :opportunity_score
      t.integer :rank

      t.timestamps
    end
  end
end
