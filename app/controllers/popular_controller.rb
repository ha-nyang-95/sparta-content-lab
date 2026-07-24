# 인기 콘텐츠 — 물질화된 급상승 스코어(성과 배수 desc)를 필터·프리로드·밴드 그룹핑만 하는 얇은 읽기 전용 컨트롤러(AD-3, 재계산 금지)
class PopularController < ApplicationController
  def index
    @period   = helpers.permitted_period(params)
    @category = helpers.permitted_category(params)
    @type     = helpers.permitted_type(params)
    @layout   = helpers.permitted_layout(params)

    # 채널 드롭다운 목록 — not_excluded 만 화이트리스트로 노출.
    @channels = Channel.not_excluded.order(:name)

    # 7.1 검색·필터·정렬 파라미터(화이트리스트·오입력 폴백).
    @q            = helpers.search_query(params)
    @min_multiple = helpers.permitted_min_multiple(params)
    @band         = helpers.permitted_band(params)
    @sort         = helpers.permitted_sort(params)
    # @channel 은 로드된 @channels(not_excluded) 에 있는 id 만 유효 — 없으면 ""(전체)로 정규화해
    # 드롭다운 라벨 공백·오입력 값이 hidden/링크로 영속되는 것을 막는다.
    @channel = params[:channel].to_s
    @channel = "" unless @channels.any? { |c| c.id.to_s == @channel }

    # 필터 무관 급상승 스코어 존재 여부 — empty 상태에서 "필터 결과 없음"과 "콜드스타트(수집 중)"를 구분.
    @has_any_scores = VideoScore.where(rank_eligible: true).where.not(performance_multiple: nil).exists?

    # base — 6.3 조건(rank_eligible + performance_multiple non-nil + 미제외 채널) 유지, 고정 정렬은 apply_sort 로 분리.
    scope = VideoScore.where(rank_eligible: true).where.not(performance_multiple: nil)
                      .joins(video: :channel).where(channels: { excluded: false })
    scope = apply_filters(scope)
    scope = apply_sort(scope)

    @scores = scope.includes(video: [:channel, :daily_stats]).to_a

    @grouped =
      if @layout == "band"
        # nil 밴드는 자기 그룹, 티어 0..3 → nil 순으로. 밴드 내 순서는 apply_sort(@sort) 결과 유지(기본 배수 desc).
        # 정렬 센티넬은 Float::INFINITY — 밴드 티어가 튜닝(AD-4)으로 늘어도 nil 이 항상 마지막.
        @scores.group_by { |s| s.video.channel.subscriber_band }
               .sort_by { |band, _| band.nil? ? Float::INFINITY : band }
      end
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

    # 7.1 채널 — @channel 은 index 에서 이미 화이트리스트 정규화됨(빈 값=전체).
    scope = scope.where(videos: { channel_id: @channel }) if @channel.present?

    # 7.1 성과 배수 프리셋 — 선택 배수 이상만.
    scope = scope.where("video_scores.performance_multiple >= ?", @min_multiple.to_f) unless @min_multiple == "all"

    # 7.1 구독자 밴드 — subscriber_count 를 scoring.yml 임계로 범위 변환(SubscriberBand 경계와 동일).
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

  # 7.1 정렬 — 선택 기준 desc + 결정적 타이브레이크 video_id asc. 기본(multiple)은 6.3 동작(배수 desc) 보존.
  def apply_sort(scope)
    case @sort
    when "views"
      scope.order(Arel.sql("videos.view_count DESC NULLS LAST")).order(video_id: :asc)
    when "recent"
      scope.order(Arel.sql("videos.published_at DESC NULLS LAST")).order(video_id: :asc)
    else
      scope.order(performance_multiple: :desc).order(video_id: :asc)
    end
  end
end
