# 주제 클러스터에 기회 점수(4입력 정규화 가중합 ×100)를 배치 물질화할 컬럼 추가(5.1, AD-3)
class AddOpportunityScoreToTopicClusters < ActiveRecord::Migration[8.1]
  def change
    add_column :topic_clusters, :opportunity_score, :float
  end
end
