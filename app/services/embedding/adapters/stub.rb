# 제목에서 결정적 가짜 벡터를 만드는 스텁 어댑터 — 키 없이 파이프라인 개발용(STUB 로그로 표식)
require "digest"

module Embedding
  module Adapters
    class Stub
      # embed(text) -> Array<Float>(길이 Config.dimensions). 같은 텍스트 → 같은 벡터(결정적).
      # 매 호출마다 "아직 진짜 아님" 표식을 로그로 남긴다(스텁을 진짜인 척 만들지 않기).
      def embed(text)
        Rails.logger.info("[Embedding] STUB 모드 — 결정적 가짜 벡터 반환(아직 진짜 임베딩 아님): #{text.to_s[0, 40]}")

        dims = Embedding::Config.dimensions
        seed = Digest::SHA256.hexdigest(text.to_s).to_i(16) % (2**63)
        rng = Random.new(seed)
        raw = Array.new(dims) { rng.rand(-1.0..1.0) }

        norm = Math.sqrt(raw.sum { |x| x * x })
        return raw if norm.zero?  # 영벡터 방어(정규화 불가 시 원 벡터 반환)

        raw.map { |x| x / norm }
      end
    end
  end
end
