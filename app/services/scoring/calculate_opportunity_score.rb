# 각 주제 클러스터의 4입력(성과·경쟁 공통성·콘텐츠 갭·최신성)을 멤버에서 집계·[0,1] 정규화·가중합 ×100 해 opportunity_score 물질화(FR-21, AD-2/3/4)
module Scoring
  class CalculateOpportunityScore
    def call
      # 가중치·정규화 파라미터는 Scoring::Config 로만 읽는다(AD-4, 하드코딩 금지).
      weights = Scoring::Config.fetch(:opportunity_score, :weights)
      norm = Scoring::Config.fetch(:opportunity_score, :normalization)
      today = Time.zone.today # Asia/Tokyo 오늘(경과일 경계 규약, 3.4와 동일).

      # 클러스터 id 순으로 결정적 배치 물질화 — 이전 스테이지가 DB에 쓴 값만 읽는다(API 무관).
      TopicCluster.transaction do
        TopicCluster.order(:id).each do |cluster|
          members = cluster.videos.includes(:channel).to_a
          scores_by_video = VideoScore.where(video_id: members.map(&:id)).index_by(&:video_id)

          perf_norm = performance_norm(members, scores_by_video, norm)
          commonality_norm = commonality_norm(members, norm)
          gap_norm = content_gap_norm(members, scores_by_video, norm)
          recency = recency_norm(members, today, norm)

          score = (
            weights[:performance_signal] * perf_norm +
            weights[:competitor_commonality] * commonality_norm +
            weights[:content_gap] * gap_norm +
            weights[:recency] * recency
          ) * 100.0

          # 0~100 계약을 구조적으로 보장 — 가중치 합·정규화가 튜닝돼도 범위를 넘지 않게(방어).
          cluster.update!(opportunity_score: score.clamp(0.0, 100.0))
        end
      end
    end

    private

    # 성과 신호 = 경쟁(is_own:false) 멤버 VideoScore.performance_multiple 최대 → min(배수/divisor, 1).
    # 경쟁 스코프인 이유: 기회 점수는 '제작할 주제' 랭킹이라 신호는 경쟁 수요다 — 자사 기존 영상 성과는 기회 아님.
    # 경쟁 신호 없으면 0(자사 전용 클러스터는 기회 0, AD-9).
    def performance_norm(members, scores_by_video, norm)
      multiples = members.reject { |v| v.channel.is_own }
                         .filter_map { |v| scores_by_video[v.id]&.performance_multiple }
      return 0.0 if multiples.empty?

      [multiples.max.to_f / norm[:performance_divisor], 1.0].min
    end

    # 경쟁 공통성 = 멤버 중 경쟁(is_own:false) 채널 distinct 수 → min(수/cap, 1). 0 이면 0.
    def commonality_norm(members, norm)
      competitor_channels = members.reject { |v| v.channel.is_own }.map(&:channel_id).uniq
      [competitor_channels.size.to_f / norm[:commonality_cap], 1.0].min
    end

    # 콘텐츠 갭 = 경쟁 멤버의 content_gap_bucket → content_gap_values 평균([0,1]). 값 없으면 0(AD-9).
    def content_gap_norm(members, scores_by_video, norm)
      values = members.filter_map do |v|
        next if v.channel.is_own

        bucket = scores_by_video[v.id]&.content_gap_bucket
        norm[:content_gap_values][bucket.to_sym] if bucket
      end
      return 0.0 if values.empty?

      values.sum / values.size
    end

    # 최신성 = 경쟁 멤버 중 최근 발행(최소 경과일) → (1 - 경과일/decay) 를 [0,1] clamp.
    # 경쟁 스코프(perf 와 동일 이유). 미래 발행(음수 경과일)도 상한 1.0 으로 clamp 해 점수 100 초과를 막는다.
    def recency_norm(members, today, norm)
      ages = members.reject { |v| v.channel.is_own }.filter_map do |v|
        (today - v.published_at.in_time_zone.to_date).to_i if v.published_at
      end
      min_age = ages.min
      return 0.0 if min_age.nil?

      (1.0 - (min_age.to_f / norm[:recency_full_decay_days])).clamp(0.0, 1.0)
    end
  end
end
