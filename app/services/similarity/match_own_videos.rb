# 경쟁×자사 영상 임베딩 코사인을 배치로 계산해 τ 이상 쌍을 OwnVideoMatch 로 idempotent 재구축(FR-17, AD-3)
module Similarity
  class MatchOwnVideos
    INSERT_SLICE = 500 # SQLite 변수 한도(~32k) 안에서 insert_all 을 배치한다.

    def call
      tau = Scoring::Config.fetch(:similarity, :tau)

      # excluded 채널은 수집·표시에서 제외한다(전 수집 스테이지 정합) — is_own 파티션 + not_excluded.
      # 각 영상의 임베딩을 1회만 unpack·정규화해 [id, 단위벡터] 로(pair 루프 norm 재계산 제거).
      own_units = unit_vectors(scope(is_own: true))
      competitor_units = unit_vectors(scope(is_own: false))

      # 한쪽이라도 비면(임베딩 대기 등) 재구축을 건너뛴다 — delete_all 이 유효 매칭을 지우지 않게(스테일 방지).
      return if own_units.empty? || competitor_units.empty?

      now = Time.current
      rows = []
      competitor_units.each do |comp_id, comp_vec|
        own_units.each do |own_id, own_vec|
          next if comp_vec.length != own_vec.length

          sim = Similarity::Cosine.dot(comp_vec, own_vec) # 단위 벡터 내적 = 코사인.
          next if sim.nil? || !sim.finite?

          sim = sim.clamp(-1.0, 1.0)
          next if sim < tau

          rows << {
            competitor_video_id: comp_id,
            own_video_id: own_id,
            similarity: sim,
            created_at: now,
            updated_at: now,
          }
        end
      end

      # 트랜잭션 내 전량 재구축 — τ 아래로 떨어진 스테일 매칭을 남기지 않는다. insert 는 배치로.
      OwnVideoMatch.transaction do
        OwnVideoMatch.delete_all
        rows.each_slice(INSERT_SLICE) { |slice| OwnVideoMatch.insert_all(slice) }
      end
    end

    private

    def scope(is_own:)
      Video.joins(:channel)
        .where(channels: { is_own: is_own, excluded: false })
        .where.not(embedding: nil)
        .order(:id)
    end

    def unit_vectors(videos)
      videos.filter_map do |video|
        unit = Similarity::Cosine.unit(video.embedding_vector)
        [video.id, unit] if unit
      end
    end
  end
end
