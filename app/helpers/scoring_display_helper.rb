# 성과 배수 밴드 클래스·라벨·편향 주석·구독자 밴드/유형 라벨을 캡슐화하는 표시 헬퍼(§1.5·§10, 읽기 전용 AD-3)
module ScoringDisplayHelper
  # §1.5 순차 그린 램프 매핑 — 색/굵기 클래스만 반환한다(칩 padding/radius `rounded-chip px-1.5 py-0.5`는 partial 담당).
  # 경계: <2 중립 / [2,5) good / [5,10] strong / >10 breakout. amber·red 금지(성과 배수).
  def performance_band_class(multiple)
    return "text-ink-muted font-normal" if multiple.nil? || multiple < 2
    return "bg-success-50 text-mult-good font-semibold" if multiple < 5
    return "bg-success-100 text-mult-strong font-bold" if multiple <= 10

    "bg-mult-breakout text-white font-bold"
  end

  # 라벨 통일(PRD §11) — 구식 표현 금지, 전 화면 이 라벨로.
  def performance_multiple_label
    "성과 배수(채널 평소 대비)"
  end

  # 시점 편향 두 기전 명명(FR-24) — (1) 누적 조회수 기준, (2) 최근 N개 젊은 기준선.
  def performance_bias_note
    "누적 조회수 기준 · 최근 N개 공개 영상의 젊은 기준선 대비 — 두 편향 상속"
  end

  # 구독자 밴드 표시 라벨을 SubscriberBand에 위임한다(nil-safe → nil).
  def subscriber_band_label(channel)
    Scoring::SubscriberBand.label(channel&.subscriber_count)
  end

  # 영상 유형 라벨 — is_short nil이면 미상(nil), true 쇼츠 / false 롱폼.
  def video_type_label(video)
    return nil if video.is_short.nil?

    video.is_short? ? "쇼츠" : "롱폼"
  end

  # 자사 유사영상 뱃지(§1.4) — 없음 neutral / 1개 caution / 2개+ danger. 물질화 own_match_count 읽기.
  def own_match_badge(count)
    if count.nil? || count.zero?
      { label: "없음", klass: "bg-badge-neutralBg text-badge-neutralFg" }
    elsif count == 1
      { label: "1개", klass: "bg-badge-cautionBg text-badge-cautionFg" }
    else
      { label: "#{count}개", klass: "bg-badge-dangerBg text-badge-dangerFg" }
    end
  end

  # 최근 7일 조회수 스냅샷을 width×height 박스에 정규화한 SVG polyline points 문자열(읽기만, AD-3).
  # 스냅샷 수 < cold_start_snapshots.sparkline 이면 nil(호출부가 콜드스타트 자리 유지). daily_stats 는 preload 전제.
  def video_sparkline_points(video, width: 96, height: 28)
    threshold = Scoring::Config.fetch(:cold_start_snapshots, :sparkline)
    stats = video.daily_stats.sort_by(&:date)
    return nil if stats.size < threshold

    values = stats.last(threshold).map(&:view_count)
    # 창 안에 결측(nil) 스냅샷이 하나라도 있으면 0으로 눌러 가짜 바닥선을 그리지 않고 콜드스타트 자리 유지(AD-9·§4.7).
    return nil if values.any?(&:nil?)

    min = values.min
    max = values.max
    n = values.size

    values.each_with_index.map { |v, i|
      x = (i.to_f / (n - 1) * width).round(1)
      # min→바닥(y=height), max→천장(y=0). 전부 동일하면 중앙 평평선.
      y = max == min ? (height / 2.0).round(1) : (height - (v - min).to_f / (max - min) * height).round(1)
      "#{x},#{y}"
    }.join(" ")
  end

  # 에버그린 정직성 상태(§4.7) — 미후보 nil / 후보이며 스냅샷<임계 :evergreen_candidate / >=임계 :evergreen_verified.
  # daily_stats 는 프리로드 전제(size 는 로드된 컬렉션 카운트 — 재쿼리 금지). 검증=관측 충분성 스냅샷 게이트(재계산 아님, AD-3).
  def evergreen_badge_status(score, video)
    return nil unless score&.evergreen_candidate

    threshold = Scoring::Config.fetch(:cold_start_snapshots, :evergreen_validation)
    video.daily_stats.size >= threshold ? :evergreen_verified : :evergreen_candidate
  end

  # 영상 길이(초) → 표시 문자열(m:ss 또는 h:mm:ss). nil·0 이하면 nil(뱃지 숨김).
  def format_duration(seconds)
    return nil if seconds.nil? || seconds.to_i <= 0

    s = seconds.to_i
    h = s / 3600
    m = (s % 3600) / 60
    sec = s % 60
    h.positive? ? format("%d:%02d:%02d", h, m, sec) : format("%d:%02d", m, sec)
  end

  # 영상 클릭 시 이동할 유튜브 watch URL. id 는 쿼리에 넣기 전 인코딩(비정규 스텁 id 의 &·공백 방어).
  def youtube_watch_url(video)
    "https://www.youtube.com/watch?v=#{CGI.escape(video.youtube_video_id.to_s)}"
  end

  # 채널 클릭 시 이동할 유튜브 채널 URL — UC id 우선, 없으면 @핸들, 둘 다 없으면 nil(링크 미생성).
  def youtube_channel_url(channel)
    if channel.youtube_channel_id.present?
      "https://www.youtube.com/channel/#{CGI.escape(channel.youtube_channel_id)}"
    elsif channel.handle.present?
      handle = channel.handle.start_with?("@") ? channel.handle : "@#{channel.handle}"
      "https://www.youtube.com/#{handle}"
    end
  end
end
