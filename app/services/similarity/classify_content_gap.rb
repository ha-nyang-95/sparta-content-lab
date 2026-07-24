# 경쟁 영상의 자사 유사영상(OwnVideoMatch) 개수·4구간 버킷을 VideoScore 에 배치 물질화(4.3, AD-3/AD-4)
module Similarity
  class ClassifyContentGap
    def call
      # '포화' 임계는 scoring.yml 단일 소재지에서만 읽는다(하드코딩 금지, AD-4).
      sat = Scoring::Config.fetch(:content_gap, :saturation_min)

      # 경쟁 영상(is_own:false, not excluded)의 VideoScore 만 분류 대상 — 자사 VideoScore 는 건드리지 않는다.
      scores = VideoScore.joins(video: :channel)
        .where(channels: { is_own: false, excluded: false })
        .order(:id)
        .to_a
      return if scores.empty?

      # 단일 grouped count 로 개수를 한 번에(영상별 COUNT N+1 제거). 매치 없는 영상은 0(→ not_made).
      counts = OwnVideoMatch.where(competitor_video_id: scores.map(&:video_id))
        .group(:competitor_video_id)
        .count

      # 개수(own_match_count)와 버킷을 같은 VideoScore 행에 함께 물질화 — 급상승 행 "N개"와 콘텐츠 갭 버킷이
      # 한 소재지·같은 개수에서 파생돼 표시가 어긋나지 않는다(FR-18 일치, AD-3 웹 요청 경로 재계산 금지).
      VideoScore.transaction do
        scores.each do |score|
          n = counts.fetch(score.video_id, 0)
          score.update!(own_match_count: n, content_gap_bucket: classify(n, sat))
        end
      end
    end

    private

    # 상호배타·전수 커버: 0→미제작, 1→유사1, 2..(sat-1)→유사2+, >=sat→포화. sat<=2 면 few 범위가 비어도 정상.
    def classify(count, sat)
      if count <= 0
        "not_made"
      elsif count == 1
        "one"
      elsif count < sat
        "few"
      else
        "saturated"
      end
    end
  end
end
