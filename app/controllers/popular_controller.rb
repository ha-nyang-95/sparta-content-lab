# 인기 콘텐츠 — 물질화된 급상승 스코어(성과 배수 desc)를 필터·프리로드·밴드 그룹핑만 하는 얇은 읽기 전용 컨트롤러(AD-3, 재계산 금지)
class PopularController < ApplicationController
  def index
    @period   = helpers.permitted_period(params)
    @category = helpers.permitted_category(params)
    @type     = helpers.permitted_type(params)

    # 필터 파라미터(화이트리스트·오입력 폴백). 정렬은 표 칼럼 헤더(§4.3, SortableHelper)로 대체.
    @q    = helpers.search_query(params)
    @band = helpers.permitted_band(params)

    # 필터 무관 급상승 스코어 존재 여부 — empty 상태에서 "필터 결과 없음"과 "콜드스타트(수집 중)"를 구분.
    @has_any_scores = VideoScore.where(rank_eligible: true).where.not(performance_multiple: nil).exists?

    # base — 6.3 조건(rank_eligible + performance_multiple non-nil + 미제외 채널). 기본 정렬은 배수 desc.
    scope = VideoScore.where(rank_eligible: true).where.not(performance_multiple: nil)
                      .joins(video: :channel).where(channels: { excluded: false })
    scope = apply_filters(scope)
    scope = helpers.apply_video_sort(scope, params, "video_scores.performance_multiple DESC NULLS LAST")

    @scores = scope.includes(video: [:channel, :daily_stats]).to_a

    # 저장 상태 — 현재 사용자의 저장 video_id 를 1회 pluck 한 Set(행별 쿼리 금지, N+1 방지).
    @saved_ids = Current.user ? Current.user.saved_videos.pluck(:video_id).to_set : Set.new
  end

  private

  # 6.2 defer 필터 실현 — 기간(업로드 경과/에버그린)·카테고리·유형을 Video/Channel 스코프에 적용(기본/all 은 미적용).
  def apply_filters(scope)
    case @period
    when "1w"        then scope = scope.where("videos.published_at >= ?", 7.days.ago)
    when "1m"        then scope = scope.where("videos.published_at >= ?", 30.days.ago)
    when "3m"        then scope = scope.where("videos.published_at >= ?", 90.days.ago)
    when "evergreen" then scope = scope.where(evergreen_candidate: true)
    end

    scope = scope.where(channels: { category: @category }) unless @category == "all"

    case @type
    when "long"  then scope = scope.where(videos: { is_short: false })
    when "short" then scope = scope.where(videos: { is_short: true })
    end

    # 7.1 키워드 — 제목 부분일치. sanitize_sql_like 로 %·_ 이스케이프 + 파라미터라이즈(인젝션 방어). 빈 문자열은 미적용.
    # SQLite LIKE 는 기본 이스케이프 문자가 없어 백슬래시가 리터럴로 취급되므로 ESCAPE '\' 를 명시해야 이스케이프가 유효하다.
    if @q.present?
      scope = scope.where("videos.title LIKE ? ESCAPE ?", "%#{Video.sanitize_sql_like(@q)}%", "\\")
    end

    # 7.1 구독자 규모 — subscriber_count 를 scoring.yml 임계로 범위 변환(SubscriberBand 경계와 동일).
    unless @band == "all"
      t = Scoring::Config.fetch(:subscriber_bands)
      case @band
      when "0" then scope = scope.where("channels.subscriber_count < ?", t[0])
      when "1" then scope = scope.where("channels.subscriber_count >= ? AND channels.subscriber_count < ?", t[0], t[1])
      when "2" then scope = scope.where("channels.subscriber_count >= ? AND channels.subscriber_count < ?", t[1], t[2])
      when "3" then scope = scope.where("channels.subscriber_count >= ?", t[2])
      end
    end

    scope
  end
end
