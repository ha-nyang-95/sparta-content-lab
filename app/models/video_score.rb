# 영상 1:1 파생 성과 점수(성과 배수·순위 적격·검증 요망) 물질화 대상 — 성과 축만, VPD와 합산 컬럼 없음(축 분리)
class VideoScore < ApplicationRecord
  belongs_to :video

  validates :video_id, uniqueness: true
end
