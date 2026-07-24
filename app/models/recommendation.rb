# 추천 주제의 생성 시점 스냅샷 — 휘발 TopicCluster에 FK 없이 참고 영상 id·라벨·기회 점수를 자체 저장(AD-10)
class Recommendation < ApplicationRecord
  serialize :reference_video_ids, coder: JSON, type: Array
end
