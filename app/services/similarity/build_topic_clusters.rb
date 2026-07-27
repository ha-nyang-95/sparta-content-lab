# 임베딩 코사인 중심(centroid) 게이트로 주제를 묶는 리더 클러스터링 — 단일연결의 체이닝(메가클러스터)을 구조적으로 차단(FR-20, AD-10)
module Similarity
  class BuildTopicClusters
    def call
      # 클러스터링 임계는 OwnVideoMatch(:tau)와 분리한 :cluster_tau — 체이닝 방지 위해 더 높다(AD-4).
      tau = Scoring::Config.fetch(:similarity, :cluster_tau)

      # 대상 = 임베딩 있는 not_excluded 영상(자사+경쟁, 일·한 교차). 영상당 1회만 정규화.
      # 확정 쇼츠(is_short=true)는 제외 — 바이럴 쇼츠(노래·예능)의 폭발적 성과배수가 추천을 오염시킨다(실측).
      # nil(유형 미확정 라이브·프리미어)·false(롱폼)는 유지. 추천은 '제작할 롱폼 주제'가 목적(AD-8 유형 분리).
      videos = Video.joins(:channel)
        .where(channels: { excluded: false })
        .where(is_short: [ false, nil ])
        .where.not(embedding: nil)
        .order(:id)
        .to_a

      units = videos.filter_map do |v|
        unit = Similarity::Cosine.unit(v.embedding_vector)
        [v.id, unit] if unit # norm 0·빈 벡터는 unit nil → 스킵.
      end

      # 대상이 비면(임베딩 일시 전량 부재 등) 재구축을 건너뛴다 — delete_all 이 유효 클러스터를 지우지 않게(4.2 대칭·스테일 방지).
      return if units.empty?

      # 리더(중심) 클러스터링 — id 순 결정적. 각 영상을 "중심 코사인이 최대"인 클러스터에 넣되, 그 값이 τ 이상일 때만.
      # 아니면 새 클러스터. 중심은 멤버 단위벡터 합을 재정규화(증분). 편입 기준이 '이웃 하나'(단일연결)가 아니라
      # '군집 중심'이라, 느슨한 다리 하나로 전체가 한 덩어리가 되는 체이닝이 구조적으로 생기지 않는다(밀도가 커져도 방지).
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
          clusters << { centroid: unit, sum: unit.dup, members: [id] }
        end
      end

      # 크기 ≥ 2 만 클러스터(고립 영상 제외). 최소 id 기준 결정적 정렬(멤버·클러스터 모두).
      components = clusters.map { |c| c[:members] }
        .select { |members| members.size >= 2 }
        .map(&:sort)
        .sort_by(&:first)

      # 휘발성 재구축 — nullify 먼저(FK 위반 방지) → delete_all → 현재 클러스터로 재생성.
      TopicCluster.transaction do
        Video.where.not(topic_cluster_id: nil).update_all(topic_cluster_id: nil)
        TopicCluster.delete_all
        components.each do |member_ids|
          cluster = TopicCluster.create!(size: member_ids.size)
          Video.where(id: member_ids).update_all(topic_cluster_id: cluster.id)
        end
      end
    end

    private

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
