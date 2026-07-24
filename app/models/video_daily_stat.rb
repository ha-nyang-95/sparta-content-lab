# 영상 조회수의 일별 스냅샷 — (video_id,date) 유니크로 하루 중복을 막는다(AD-5)
class VideoDailyStat < ApplicationRecord
  belongs_to :video

  validates :date, presence: true
  validates :video_id, uniqueness: { scope: :date }
end
