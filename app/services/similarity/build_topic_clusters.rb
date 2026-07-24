# 임베딩 코사인 ≥ τ 간선의 연결요소(union-find)를 휘발성 TopicCluster 로 배치 재구축(FR-20, AD-10)
module Similarity
  class BuildTopicClusters
    def call
      tau = Scoring::Config.fetch(:similarity, :tau)

      # 대상 = 임베딩 있는 not_excluded 영상(자사+경쟁, 일·한 교차). 영상당 1회만 정규화.
      videos = Video.joins(:channel)
        .where(channels: { excluded: false })
        .where.not(embedding: nil)
        .order(:id)
        .to_a

      units = videos.filter_map do |v|
        unit = Similarity::Cosine.unit(v.embedding_vector)
        [v.id, unit] if unit # norm 0·빈 벡터는 unit nil → 스킵.
      end

      # 대상이 비면(임베딩 일시 전량 부재 등) 재구축을 건너뛴다 — delete_all 이 유효 클러스터를 지우지 않게(4.2 대칭·스테일 방지).
      return if units.empty?

      # union-find — 대표는 최소 id 로 고정해 결정적. i<j 쌍 코사인 ≥ τ 이면 union.
      parent = {}
      units.each { |id, _| parent[id] = id }

      units.each_with_index do |(id_i, unit_i), i|
        ((i + 1)...units.length).each do |j|
          id_j, unit_j = units[j]
          sim = Similarity::Cosine.dot(unit_i, unit_j) # 단위 벡터 내적 = 코사인.
          next if sim.nil? || !sim.finite?
          next if sim < tau

          union(parent, id_i, id_j)
        end
      end

      # 연결요소로 그룹핑 → 크기 ≥ 2 만 클러스터(고립 영상 제외). 최소 id 기준 결정적 정렬.
      components = units.map { |id, _| id }.group_by { |id| find(parent, id) }
        .values
        .select { |members| members.size >= 2 }
        .map(&:sort)
        .sort_by(&:first)

      # 휘발성 재구축 — nullify 먼저(FK 위반 방지) → delete_all → 현재 그래프로 재생성.
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

    # 경로 압축 find — 트리를 평탄화해 반복 조회를 상수화한다.
    def find(parent, id)
      root = id
      root = parent[root] while parent[root] != root
      while parent[id] != root
        parent[id], id = root, parent[id]
      end
      root
    end

    # 큰 root 를 작은 root 밑에 붙여 대표를 최소 id 로 유지(결정성).
    def union(parent, a, b)
      ra = find(parent, a)
      rb = find(parent, b)
      return if ra == rb

      lo, hi = ra < rb ? [ra, rb] : [rb, ra]
      parent[hi] = lo
    end
  end
end
