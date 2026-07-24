# 경쟁 채널 화면(6.4) 표시 헬퍼 — 구독자 증감 3상태·아바타 이니셜/파스텔(전부 저장 스냅샷 읽기, AD-3)
module CompetitorsHelper
  # 아바타 파스텔 팔레트 — DESIGN §10 badge/surface 토큰 쌍만(원시 색 발명 금지). 채널명 해시로 결정적 선택.
  AVATAR_PALETTE = [
    "bg-primary-50 text-primary-600",
    "bg-success-50 text-success-600",
    "bg-badge-neutralBg text-badge-neutralFg",
    "bg-badge-cautionBg text-badge-cautionFg"
  ].freeze

  # 프리로드된 daily_stats(재쿼리 금지)를 date asc 로 읽어 7일 창 구독자 증감 3상태를 산출한다(순수 표시 변환).
  def subscriber_delta_state(channel)
    threshold = Scoring::Config.fetch(:cold_start_snapshots, :subscriber_delta)
    stats = channel.daily_stats.sort_by(&:date)

    return { state: :collecting, days: stats.size } if stats.size < threshold

    window = stats.last(threshold)
    e = window.first.subscriber_count
    l = window.last.subscriber_count

    # 양 끝점 중 하나라도 nil/0(회원 전용·구독자 숨김)이면 퍼센트 기준이 없다 — 자리 유지하며 수집 중으로(AD-9).
    # 특히 latest nil 을 0 으로 강압하면 건강한 채널이 −100% 붕괴로 오표시된다(정직성 §4.7).
    return { state: :collecting, days: stats.size } if e.nil? || e.zero? || l.nil?

    pct = (l - e).to_f / e * 100

    return { state: :immaterial } if pct.abs < Scoring::Config.fetch(:subscriber_delta, :min_material_pct)

    { state: :material, pct: pct, direction: (pct >= 0 ? :up : :down) }
  end

  # 증감% 절대값을 표시 상수 bar_full_pct(데이터 아님) 대비 0..100 으로 클램프한 진행 바 너비(%).
  def subscriber_delta_bar_width(pct)
    full = Scoring::Config.fetch(:subscriber_delta, :bar_full_pct)
    (pct.abs / full * 100).round.clamp(0, 100)
  end

  # 채널명 첫 grapheme 대문자. 이름 없으면 "?".
  def avatar_initial(name)
    first = name.to_s.strip.chars.first
    first.nil? ? "?" : first.upcase
  end

  # 채널명 해시로 §10 파스텔 토큰 쌍을 결정적으로 고른다(같은 이름 → 항상 같은 색).
  def avatar_style(name)
    index = name.to_s.each_char.sum(&:ord) % AVATAR_PALETTE.size
    AVATAR_PALETTE[index]
  end
end
