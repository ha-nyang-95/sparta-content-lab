# 대시보드 홈 필터 파라미터 화이트리스트·위젯 콜드스타트 준비도·추천 카드 파생값 헬퍼(읽기 전용 AD-3)
module DashboardHelper
  # 기간 탭 순서·라벨(§4.8 세그먼트) — 업로드 기간 필터 + 에버그린.
  PERIODS = [%w[1w 최근\ 1주], %w[1m 1개월], %w[3m 3개월], %w[evergreen 에버그린]].freeze
  # 카테고리 드롭다운 화이트리스트(전체 + 4분류 표시 라벨).
  CATEGORIES = [%w[all 전체], %w[한국어교육일반 한국어\ 교육], %w[언어교육참고 영어\ 교육], %w[직접경쟁 직접경쟁], %w[상단퍼널 일반\ 영상]].freeze
  # 유형 드롭다운 화이트리스트(전체/롱폼/쇼츠).
  TYPES = [%w[all 전체], %w[long 롱폼], %w[short 쇼츠]].freeze
  # 레이아웃 토글 화이트리스트(구독자 밴드 그룹핑 ↔ 평면).
  LAYOUTS = [%w[band 밴드\ 그룹핑], %w[flat 평면]].freeze

  def period_tabs
    PERIODS
  end

  def category_options
    CATEGORIES
  end

  def type_options
    TYPES
  end

  def layout_options
    LAYOUTS
  end

  # params 값이 화이트리스트에 없으면 기본값으로 안전 폴백(오입력 방어).
  def permitted_period(params)
    whitelist_param(params[:period], PERIODS, "1w")
  end

  def permitted_category(params)
    whitelist_param(params[:category], CATEGORIES, "all")
  end

  def permitted_type(params)
    whitelist_param(params[:type], TYPES, "all")
  end

  def permitted_layout(params)
    whitelist_param(params[:layout], LAYOUTS, "band")
  end

  # 위젯별 준비도(AD-7) — 실제 스냅샷 일수 < cold_start_snapshots 임계면 "수집 중".
  def widget_collecting?(widget)
    widget_snapshot_count(widget) < Scoring::Config.fetch(:cold_start_snapshots, widget)
  end

  # "D+n · 데이터 수집 중" 상세 문구(개별 위젯 자리 유지).
  def widget_collecting_detail(widget)
    "D+#{widget_snapshot_count(widget)} · 데이터 수집 중"
  end

  # 자격 미달 추천은 억지로 채우지 않고 확보 개수만 안내(정직성 AD-16).
  def recommendation_shortfall_note(count, target)
    return nil if count >= target

    "이번 주 #{count}개 확보"
  end

  # 참고 영상들의 성과 배수 중 최대(물질화 읽기, 없으면 nil).
  def recommendation_multiple(recommendation, videos_by_rec)
    recommendation.reference_video_ids
                  .filter_map { |id| videos_by_rec[id]&.video_score&.performance_multiple }
                  .max
  end

  # 참고 영상 중 자사 유사영상(own_match_count>0)이 하나라도 있으면 true.
  def recommendation_has_own_match?(recommendation, videos_by_rec)
    recommendation.reference_video_ids.any? do |id|
      (videos_by_rec[id]&.video_score&.own_match_count || 0).positive?
    end
  end

  private

  # 시계열 위젯의 스냅샷 일수 — 구독자 증감은 채널 스냅샷, 나머지는 영상 스냅샷.
  # 요청당 memoize — collecting? 와 detail 이 같은 위젯을 반복 조회해도 COUNT 를 한 번만.
  def widget_snapshot_count(widget)
    source = widget == :subscriber_delta ? :channel : :video
    (@widget_snapshot_counts ||= {})[source] ||=
      (source == :channel ? ChannelDailyStat : VideoDailyStat).distinct.count(:date)
  end

  def whitelist_param(value, options, default)
    keys = options.map(&:first)
    keys.include?(value) ? value : default
  end
end
