# 경쟁 영상↔자사 영상 유사 매칭(τ 이상) 물질화 레코드 — 콘텐츠 갭·급상승 행 자사 유사영상 근거(FR-17)
class OwnVideoMatch < ApplicationRecord
  belongs_to :competitor_video, class_name: "Video"
  belongs_to :own_video, class_name: "Video"

  validates :own_video_id, uniqueness: { scope: :competitor_video_id }
end
