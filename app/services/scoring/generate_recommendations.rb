# 기회 점수 상위 주제 클러스터를 결정적 정렬로 최대 max_count개 뽑아 Recommendation 스냅샷으로 물질화(FR-19, AD-10/16)
module Scoring
  class GenerateRecommendations
    def call
      max_count = Scoring::Config.fetch(:recommendation, :max_count)
      today = Time.zone.today

      # 상류 기회 점수 스테이지가 실패/미실행이면(클러스터는 있는데 아무도 점수 계산 안 됨) 재구축을 건너뛴다 —
      # delete_all 이 어제의 유효 추천을 지우지 않게(스테일 방지). 정직한 '자격 0'(점수 계산됐으나 아무도 >0)과 구분.
      return if TopicCluster.exists? && TopicCluster.where.not(opportunity_score: nil).none?

      # 자격 = opportunity_score > 0(경쟁 신호 있는 클러스터). > 0 SQL 은 NULL 도 제외한다.
      clusters = TopicCluster.where("opportunity_score > 0").includes(videos: :channel).to_a

      # 전 멤버 VideoScore 를 한 번에 로드해 클러스터별 tie 계산에서 N+1 을 피한다.
      all_member_ids = clusters.flat_map { |c| c.videos.map(&:id) }
      scores_by_video = VideoScore.where(video_id: all_member_ids).index_by(&:video_id)

      # 매 배치 delete_all 후 타입(롱폼/숏폼)별로 상위 max_count 개를 재구축 — 스냅샷이라 자체 완결·FK 없음.
      # 랭크는 타입 내부에서 1..max_count. 대시보드 토글이 video_type 으로 골라 읽는다(같은 공식·풀만 분리).
      Recommendation.transaction do
        Recommendation.delete_all
        clusters.group_by(&:video_type).each do |video_type, type_clusters|
          # 결정적 정렬: 기회 점수 desc → 경쟁 성과 배수 desc → 최신성(경과일 asc = 최근 먼저) → 클러스터 id asc.
          sorted = type_clusters.sort_by do |cluster|
            [-cluster.opportunity_score, -tie_perf(cluster, scores_by_video), tie_min_age(cluster, today), cluster.id]
          end
          sorted.first(max_count).each_with_index do |cluster, i|
            Recommendation.create!(
              video_type: video_type,
              topic_label: topic_label_for(cluster, scores_by_video),
              opportunity_score: cluster.opportunity_score,
              reference_video_ids: reference_video_ids_for(cluster),
              rank: i + 1
            )
          end
        end
      end
    end

    private

    # 클러스터의 경쟁(is_own:false) 멤버.
    def competitors(cluster)
      cluster.videos.reject { |v| v.channel.is_own }
    end

    # 동점 성과 배수 = 경쟁 멤버 performance_multiple 최대(없으면 0.0).
    def tie_perf(cluster, scores_by_video)
      multiples = competitors(cluster).filter_map { |v| scores_by_video[v.id]&.performance_multiple }
      multiples.max || 0.0
    end

    # 동점 최신성 = 경쟁 멤버 중 최소 경과일(발행일 없으면 무한대 → 최신성에서 뒤로).
    def tie_min_age(cluster, today)
      ages = competitors(cluster).filter_map do |v|
        (today - v.published_at.in_time_zone.to_date).to_i if v.published_at
      end
      ages.min || Float::INFINITY
    end

    # 참고 영상 id = 경쟁 멤버 영상 id(결정적으로 정렬).
    def reference_video_ids_for(cluster)
      competitors(cluster).map(&:id).sort
    end

    # 대표 주제명 = 경쟁 멤버 중 성과 배수 최고 영상 제목(동점은 video id asc). 제목 폴백도 경쟁 멤버 안에서만
    # (자사 영상 제목이 주제명이 되지 않게). 경쟁 제목이 모두 없으면 안전 플레이스홀더.
    def topic_label_for(cluster, scores_by_video)
      members = competitors(cluster)
      rep = members.max_by { |v| [scores_by_video[v.id]&.performance_multiple || -Float::INFINITY, -v.id] }
      rep&.title.presence || members.filter_map { |v| v.title.presence }.first || "미분류 주제"
    end
  end
end
