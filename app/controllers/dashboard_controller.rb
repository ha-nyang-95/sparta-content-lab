# 대시보드 홈(root) — 물질화된 추천·참고 영상·필터 파라미터만 읽는 얇은 컨트롤러(AD-3, 재계산 금지)
class DashboardController < ApplicationController
  def index
    @recommendations = Recommendation.order(:rank)
    reference_ids = @recommendations.flat_map(&:reference_video_ids).uniq
    @videos_by_rec = Video.where(id: reference_ids)
                          .includes(:video_score, :channel)
                          .index_by(&:id)

    @period   = helpers.permitted_period(params)
    @category = helpers.permitted_category(params)
    @type     = helpers.permitted_type(params)
    @layout   = helpers.permitted_layout(params)
    @max_recommendations = Scoring::Config.fetch(:recommendation, :max_count)

    # 에버그린 후보(6.6) — 물질화 flag 만 읽어 배수 desc 로 상위 로드(읽기 전용, N+1 프리로드).
    @evergreen_scores = VideoScore.where(evergreen_candidate: true)
                                  .joins(video: :channel)
                                  .where(channels: { excluded: false })
                                  .includes(video: [:channel, :daily_stats])
                                  .order(performance_multiple: :desc)
                                  .order(video_id: :asc) # 동점 시 결정적 — ranked 규약과 동일 타이브레이크.
                                  .limit(5)
                                  .to_a

    # 요약 위젯 — 시계열(스냅샷)이 얕아도 물질화된 값으로 "최선 데이터"를 보여준다(콜드 시 하단에 안내 문구).
    # 급상승: 경쟁 상위 성과 배수(배수 자체는 스냅샷 없이도 물질화됨). 옆 박스 높이를 채우도록 넉넉히 로드.
    @top_scores = VideoScore.ranked.joins(video: :channel)
                            .where(channels: { excluded: false, is_own: false })
                            .includes(video: [:channel, :video_score])
                            .limit(10).to_a
    # 경쟁 채널 동향: 구독자 상위(증감은 콜드여도 채널·구독자는 표시).
    @top_competitors = Channel.competitor.not_excluded
                              .includes(:daily_stats)
                              .order(Arel.sql("subscriber_count DESC NULLS LAST")).order(:id)
                              .limit(5).to_a
    # 콘텐츠 기회 도넛: 경쟁 분류 스코어 버킷 분포(content_gap/_donut 재사용 — @distribution 소비).
    @distribution = VideoScore.joins(video: :channel)
                              .where(channels: { is_own: false, excluded: false })
                              .where.not(content_gap_bucket: nil)
                              .group(:content_gap_bucket).count
  end
end
