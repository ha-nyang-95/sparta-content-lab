# 채널에 속한 유튜브 영상 메타 — 통계(view/like/comment) nil 허용(회원전용·누락 방어, AD-9)
class Video < ApplicationRecord
  belongs_to :channel

  validates :youtube_video_id, presence: true, uniqueness: true
end
