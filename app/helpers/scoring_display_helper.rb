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
end
