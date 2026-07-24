# 채널에 속한 유튜브 영상 메타 — 통계(view/like/comment) nil 허용(회원전용·누락 방어, AD-9)
class Video < ApplicationRecord
  belongs_to :channel
  belongs_to :topic_cluster, optional: true
  has_one :video_score
  has_many :daily_stats, class_name: "VideoDailyStat", dependent: :destroy

  validates :youtube_video_id, presence: true, uniqueness: true

  # packed-float BLOB 임베딩을 Array<Float> 로 되돌린다(embedding 없으면 nil). 4.2 코사인이 소비.
  def embedding_vector
    embedding && embedding.unpack("f*")
  end
end
