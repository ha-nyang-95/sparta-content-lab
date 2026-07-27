# 콘텐츠 갭 화면 — 물질화된 경쟁 영상 content_gap_bucket 을 집계·프리로드만 하는 얇은 읽기 전용 컨트롤러(AD-3, 재계산 금지)
class ContentGapController < ApplicationController
  def index
    # 경쟁 영상(is_own:false, not excluded)의 분류된 스코어만 — 자사·미분류(nil) 제외.
    base = VideoScore.joins(video: :channel)
                     .where(channels: { is_own: false, excluded: false })
                     .where.not(content_gap_bucket: nil)

    # 4구간 분포 집계(표시 변환 소재) — {"not_made"=>n, ...}.
    @distribution = base.group(:content_gap_bucket).count

    # 화이트리스트 검증한 선택 구간(기본 not_made).
    @bucket = helpers.permitted_content_gap_bucket(params)

    # 선택 구간 영상 — 기본 성과 배수 desc, 표 칼럼 헤더로 정렬 변경(SortableHelper). N+1 프리로드.
    scope = base.where(content_gap_bucket: @bucket).includes(video: [:channel, :daily_stats])
    @scores = helpers.apply_video_sort(scope, params, "video_scores.performance_multiple DESC NULLS LAST").to_a
  end
end
