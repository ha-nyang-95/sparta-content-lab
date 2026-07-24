# 제목 있는 영상의 임베딩을 배치 물질화 — 신규·제목 변경·출처 변경 행만 재생성해 과금 최소화(AD-10)
require "digest"

module Embedding
  class UpsertVectors
    def initialize(client: Embedding::Client.new)
      @client = client
    end

    # 각 영상의 source_hash = SHA256(출처 | 제목). 임베딩이 있고 해시가 일치하면 스킵(무호출).
    # 출처(mode|model|dimensions)를 해시에 포함해, 키 도착 후 stub→live 전환·모델·차원 변경 시
    # 제목이 같아도 재생성되게 한다(가짜 stub 벡터가 영구 잔존하지 않게). 신규·변경만 embed 호출.
    def call
      provenance = "#{Embedding::Config.mode}|#{Embedding::Config.model}|#{Embedding::Config.dimensions}"

      Video.where.not(title: [nil, ""]).find_each do |video|
        next if video.title.blank? # SQL where.not 이 못 거르는 공백만("   ") 제목 방어(AD-9).

        source_hash = Digest::SHA256.hexdigest("#{provenance}|#{video.title}")
        next if video.embedding.present? && video.embedding_source_hash == source_hash

        # 후보별 rescue — 한 영상 embed 실패(live 키 대기·네트워크·타임아웃)가 나머지 배치를 버리지 않는다.
        begin
          vector = @client.embed(video.title)
          video.update!(embedding: vector.pack("f*"), embedding_source_hash: source_hash)
        rescue => e
          Rails.logger.warn("[Embedding] 임베딩 실패(스킵): video##{video.id} — #{e.class}: #{e.message}")
        end
      end
    end
  end
end
