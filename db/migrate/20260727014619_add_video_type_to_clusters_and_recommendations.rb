# 주제 클러스터·추천을 롱폼/숏폼 타입별로 분리 물질화하기 위한 video_type 컬럼(휘발 데이터라 nullable, 재구축이 채움)
class AddVideoTypeToClustersAndRecommendations < ActiveRecord::Migration[8.1]
  def change
    add_column :topic_clusters, :video_type, :string
    add_column :recommendations, :video_type, :string
  end
end
