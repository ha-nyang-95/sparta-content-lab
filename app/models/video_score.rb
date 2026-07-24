# 영상 1:1 파생 성과 점수(성과 배수·순위 적격·검증 요망) 물질화 대상 — 성과 축만, VPD와 합산 컬럼 없음(축 분리)
class VideoScore < ApplicationRecord
  belongs_to :video

  validates :video_id, uniqueness: true

  # 콘텐츠 갭 4구간(4.3) — Similarity::ClassifyContentGap 이 경쟁 영상 VideoScore 에만 물질화.
  CONTENT_GAP_BUCKETS = %w[not_made one few saturated].freeze

  # 화이트리스트 검증 — classify 오타가 조용히 영속되지 않게 한다(nil 은 미분류 자사·경쟁 영상).
  validates :content_gap_bucket, inclusion: { in: CONTENT_GAP_BUCKETS }, allow_nil: true

  # 기본 정렬키 — 성과 배수 내림차순 + video_id 오름차순 결정적 타이브레이크, rank_eligible=false 제외(raw 조회수 정렬 금지).
  # performance_multiple nil 도 명시 제외 — 3.2 불변식(nil 배수→rank_eligible false)에만 의존하지 않는 방어(NULL 정렬 회피).
  scope :ranked, -> { where(rank_eligible: true).where.not(performance_multiple: nil).order(performance_multiple: :desc, video_id: :asc) }
end
