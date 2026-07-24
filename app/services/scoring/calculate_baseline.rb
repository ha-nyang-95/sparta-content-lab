# 채널·유형별 최근 N개 공개 영상 view_count 중앙값·표본·저신뢰를 계산해 Baseline 으로 물질화(순수 계산, API 무관, AD-2)
module Scoring
  class CalculateBaseline
    # (video_type, is_short 불리언) — 쇼츠와 롱폼은 독립 행으로 물질화(AD-8, 절대 미공유).
    TYPES = [["short", true], ["long", false]].freeze

    def initialize(channel)
      @channel = channel
    end

    def call
      # 두 유형을 한 트랜잭션으로 물질화 — long 저장 실패가 short만 갱신된 부분 상태를 남기지 않게 한다.
      Baseline.transaction do
        TYPES.each do |video_type, is_short|
          view_counts = collect_view_counts(is_short)
          sample_size = view_counts.size
          low_confidence = sample_size < Scoring::Config.fetch(:baseline, :min_sample_for_confidence)

          baseline = Baseline.find_or_initialize_by(channel: @channel, video_type: video_type)
          baseline.update!(
            median_view_count: median(view_counts),
            sample_size: sample_size,
            low_confidence: low_confidence
          )
        end
      end
    end

    private

    # 유형 확정(is_short non-nil) + 공개(view_count non-nil)만, 최근 N개 결정적 선택.
    def collect_view_counts(is_short)
      @channel.videos
              .where(is_short: is_short)
              .where.not(view_count: nil)
              .order(published_at: :desc, id: :desc)
              .limit(Scoring::Config.fetch(:baseline, :sample_size_n))
              .pluck(:view_count)
    end

    # 오름차순 정렬 후 홀수=가운데, 짝수=가운데 두 값 평균. 항상 Float 반환(홀짝 계약 통일).
    # 빈 배열이면 nil, 전량 0-조회수면 0.0 — 3.2 성과 배수는 median 이 nil/0 인 기준선을 나눗셈 방어해야 한다.
    def median(values)
      return nil if values.empty?

      sorted = values.sort
      mid = sorted.size / 2
      if sorted.size.odd?
        sorted[mid].to_f
      else
        (sorted[mid - 1] + sorted[mid]) / 2.0
      end
    end
  end
end
