# 영상 기획 분석 캐시 — 자막 기반 Gemini 분석 결과(온디맨드 생성·영상당 1행). status=ok 만 본문 유효.
class VideoAnalysis < ApplicationRecord
  belongs_to :video

  STATUSES = %w[ok unavailable].freeze
  validates :status, inclusion: { in: STATUSES }

  def ok?
    status == "ok"
  end
end
