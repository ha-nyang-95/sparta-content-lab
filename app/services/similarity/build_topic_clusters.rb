# 임베딩 코사인 중심(centroid) 게이트로 주제를 묶는 리더 클러스터링 — 단일연결의 체이닝(메가클러스터)을 구조적으로 차단(FR-20, AD-10)
module Similarity
  class BuildTopicClusters
    # 타입별 풀 정의 — 롱폼/숏폼은 성과 동학이 달라 섞지 않고 독립 클러스터링(AD-8 기준선 분리를 추천까지 확장).
    # long = 롱폼(false) + 유형 미확정(nil, 라이브·프리미어). short = 확정 쇼츠(true).
    TYPE_SCOPES = { "long" => [ false, nil ], "short" => [ true ] }.freeze

    def call
      # 클러스터링 임계는 OwnVideoMatch(:tau)와 분리한 :cluster_tau — 체이닝 방지 위해 더 높다(AD-4).
      tau = Scoring::Config.fetch(:similarity, :cluster_tau)

      # 타입별로 단위벡터를 독립 로드 — 바이럴 쇼츠가 롱폼 추천을 오염시키지 않게 풀 자체를 분리한다(실측).
      pools = TYPE_SCOPES.map do |video_type, is_short_values|
        videos = Video.joins(:channel)
          .where(channels: { excluded: false })
          .where(is_short: is_short_values)
          .where.not(embedding: nil)
          .order(:id)
          .to_a
        units = videos.filter_map do |v|
          unit = Similarity::Cosine.unit(v.embedding_vector)
          [ v.id, unit ] if unit # norm 0·빈 벡터는 unit nil → 스킵.
        end
        [ video_type, units ]
      end

      # 전 타입에 units(임베딩)가 전무하면(임베딩 일시 전량 부재 등) 재구축을 건너뛴다 — delete_all 이 유효 클러스터를
      # 지우지 않게(4.2 대칭·스테일 방지). '임베딩은 있으나 아무도 안 묶임(전부 고립)'은 유효 상태라 재구축 진행(빈 결과 반영).
      return if pools.all? { |_type, units| units.empty? }

      # 휘발성 재구축 — nullify 먼저(FK 위반 방지) → delete_all → 타입별 클러스터로 재생성(video_type 태깅).
      TopicCluster.transaction do
        Video.where.not(topic_cluster_id: nil).update_all(topic_cluster_id: nil)
        TopicCluster.delete_all
        pools.each do |video_type, units|
          cluster_units(units, tau).each do |member_ids|
            cluster = TopicCluster.create!(size: member_ids.size, video_type: video_type)
            Video.where(id: member_ids).update_all(topic_cluster_id: cluster.id)
          end
        end
      end
    end

    private

    # 단위벡터 목록([id, unit]...)을 리더(중심) 클러스터링해 크기≥2 연결요소(정렬된 video_id 배열들)를 결정적으로 반환.
    # 각 영상을 "중심 코사인이 최대"인 클러스터에 넣되 그 값이 τ 이상일 때만, 아니면 새 클러스터. 중심은 멤버 단위벡터 합을
    # 재정규화(증분). 편입 기준이 '이웃 하나'(단일연결)가 아니라 '군집 중심'이라, 느슨한 다리 하나로 전체가 한 덩어리가
    # 되는 체이닝이 구조적으로 생기지 않는다(밀도가 커져도 방지).
    def cluster_units(units, tau)
      clusters = [] # 각 원소: { centroid: 단위벡터, sum: 원합, members: [video_id...] }

      units.each do |id, unit|
        best = nil
        best_sim = -2.0
        clusters.each_with_index do |cluster, idx|
          sim = Similarity::Cosine.dot(unit, cluster[:centroid]) # 둘 다 단위벡터 → 내적 = 코사인.
          next if sim.nil? || !sim.finite?
          if sim > best_sim # strict → 동점이면 먼저 만든(작은 idx) 클러스터 유지(결정성).
            best_sim = sim
            best = idx
          end
        end

        if best && best_sim >= tau
          cluster = clusters[best]
          cluster[:sum] = add_vectors(cluster[:sum], unit)
          cluster[:members] << id
          cluster[:centroid] = Similarity::Cosine.unit(cluster[:sum]) || cluster[:centroid] # 합 norm 0 방어.
        else
          clusters << { centroid: unit, sum: unit.dup, members: [ id ] }
        end
      end

      # 크기 ≥ 2 만 클러스터(고립 영상 제외). 최소 id 기준 결정적 정렬(멤버·클러스터 모두).
      clusters.map { |c| c[:members] }
        .select { |members| members.size >= 2 }
        .map(&:sort)
        .sort_by(&:first)
    end

    # 두 동일 길이 벡터의 원소합(증분 중심용 — 새 배열 반환, 입력 불변).
    def add_vectors(a, b)
      out = Array.new(a.length)
      i = 0
      while i < a.length
        out[i] = a[i] + b[i]
        i += 1
      end
      out
    end
  end
end
