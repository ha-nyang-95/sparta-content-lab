# 구독자 수를 scoring.yml 임계로 4티어(0..3, 포함 하한) 분류하는 순수 함수 — 밴드 계산·라벨(물질화 없음, 그룹핑 축)
module Scoring
  module SubscriberBand
    LABELS = ["<1만", "1만~10만", "10만~50만", "50만+"].freeze

    # 구독자 수를 티어 정수(0..3)로. nil이면 밴드 미상(nil). 포함 하한 — 임계 이상이면 상위 티어.
    def self.tier(subscriber_count)
      return nil if subscriber_count.nil?

      Scoring::Config.fetch(:subscriber_bands).count { |threshold| subscriber_count >= threshold }
    end

    # 티어에 대응하는 표시 라벨. nil 티어면 nil.
    def self.label(subscriber_count)
      t = tier(subscriber_count)
      return nil if t.nil?

      ensure_labels_cover!
      LABELS[t]
    end

    # LABELS 와 subscriber_bands 티어 수 정합 검증 — scoring.yml 밴드 개수를 바꾸면(AD-4 튜닝)
    # LABELS 도 함께 갱신하도록 fail-fast(조용히 LABELS[t]=nil 을 반환하는 드리프트 방지).
    def self.ensure_labels_cover!
      expected = Scoring::Config.fetch(:subscriber_bands).length + 1
      return if LABELS.length == expected

      raise KeyError,
        "SubscriberBand LABELS(#{LABELS.length}개)가 subscriber_bands 티어 수(#{expected}개)와 불일치 — scoring.yml 밴드 변경 시 LABELS 갱신 필요"
    end
  end
end
