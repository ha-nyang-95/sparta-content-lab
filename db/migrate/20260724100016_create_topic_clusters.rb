# 휘발성 주제 클러스터(연결요소)와 영상 멤버십 FK — 배치마다 재구축(AD-10, 4.4)
class CreateTopicClusters < ActiveRecord::Migration[8.1]
  def change
    create_table :topic_clusters do |t|
      t.integer :size

      t.timestamps
    end

    add_reference :videos, :topic_cluster, foreign_key: true, index: true
  end
end
