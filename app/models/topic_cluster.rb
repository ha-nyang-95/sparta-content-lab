# 임베딩 연결요소로 묶인 휘발성 주제 클러스터 — 배치마다 재구축, 멤버는 videos.topic_cluster_id (AD-10, 4.4)
class TopicCluster < ApplicationRecord
  has_many :videos, dependent: :nullify
end
