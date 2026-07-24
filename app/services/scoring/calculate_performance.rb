# 영상별 성과 배수(= 누적 view_count ÷ 채널·유형 기준선 중앙값)·조회수 하한·극단 배수 플래그를 배치 물질화(순수 계산, API 무관, AD-2/AD-3)
module Scoring
  class CalculatePerformance
    def initialize(channel)
      @channel = channel
    end

    def call
      # 채널의 유형별 기준선을 1회 로드 — {"short"=>b, "long"=>b}.
      baselines = Baseline.where(channel: @channel).index_by(&:video_type)

      # 튜닝값은 Scoring::Config 로만 읽는다(AD-4, 하드코딩 금지).
      fixed = Scoring::Config.fetch(:performance, :view_floor_fixed)
      k = Scoring::Config.fetch(:performance, :view_floor_k)
      extreme = Scoring::Config.fetch(:performance, :extreme_multiple)

      # 전체를 한 트랜잭션으로 물질화 — 부분 상태를 남기지 않는다(3.1 계약 승계).
      VideoScore.transaction do
        # is_short nil(유형 미확정) 영상은 유형 기준선을 못 고르므로 점수 미물질화(행 없음).
        @channel.videos.where.not(is_short: nil).each do |video|
          video_type = video.is_short? ? "short" : "long"
          baseline = baselines[video_type]
          median = baseline&.median_view_count

          # 퇴화 기준선 방어(3.1 계약 승계): view_count nil·기준선 부재·median nil·median<=0 이면
          # 나눗셈에 도달하지 않고 배수 미계산(Infinity·ZeroDivisionError 절대 금지).
          if video.view_count.nil? || baseline.nil? || median.nil? || median <= 0
            performance_multiple = nil
            rank_eligible = false
            needs_verification = false
          else
            performance_multiple = video.view_count.to_f / median
            floor = [fixed, k * median].max
            rank_eligible = video.view_count >= floor
            needs_verification = performance_multiple > extreme
          end

          VideoScore.find_or_initialize_by(video: video).update!(
            performance_multiple: performance_multiple,
            rank_eligible: rank_eligible,
            needs_verification: needs_verification
          )
        end
      end
    end
  end
end
