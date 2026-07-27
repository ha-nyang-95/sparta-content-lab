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
    # progress: 선택 콜백(done, total). 스캔한 영상 수 기준으로 게이지 진행을 알린다(50개마다 throttle).
    # total 은 제목 있는 영상 수(상한) — 이미 임베딩된 영상은 스킵되지만 스캔은 하므로 done 은 스킵 포함 증가한다.
    def call(progress: nil)
      provenance = "#{Embedding::Config.mode}|#{Embedding::Config.model}|#{Embedding::Config.dimensions}"
      total = progress ? Video.where.not(title: [nil, ""]).count : 0
      done = 0

      Video.where.not(title: [nil, ""]).find_each do |video|
        done += 1
        if video.title.blank? # SQL where.not 이 못 거르는 공백만("   ") 제목 방어(AD-9).
          notify_progress(progress, done, total)
          next
        end

        source_hash = Digest::SHA256.hexdigest("#{provenance}|#{video.title}")
        if video.embedding.present? && video.embedding_source_hash == source_hash
          notify_progress(progress, done, total)
          next
        end

        # 후보별 rescue — 한 영상 embed 실패(live 키 대기·네트워크·타임아웃)가 나머지 배치를 버리지 않는다.
        begin
          vector = @client.embed(video.title)
          video.update!(embedding: vector.pack("f*"), embedding_source_hash: source_hash)
        rescue => e
          Rails.logger.warn("[Embedding] 임베딩 실패(스킵): video##{video.id} — #{e.class}: #{e.message}")
        end
        notify_progress(progress, done, total)
      end
    end

    private

    # 50개마다 또는 마지막에만 콜백 호출(진행 기록 DB 쓰기 throttle).
    def notify_progress(progress, done, total)
      return unless progress
      progress.call(done, total) if (done % 50).zero? || done == total
    end
  end
end
