# 모든 Gemini 임베딩 호출의 단일 공개 경계 — 모드로 adapter 를 선택하고 테스트가 주입할 수 있다(AD-1)
module Embedding
  class Client
    # adapter 는 mode 로 기본 선택하되 테스트가 fake 를 주입할 수 있다.
    def initialize(mode: Embedding::Config.mode, adapter: nil)
      @adapter = adapter || default_adapter(mode)
    end

    # embed(text) -> Array<Float>. 빈 텍스트는 방어(UpsertVectors 가 이미 걸러도 이중 안전).
    def embed(text)
      raise ArgumentError, "빈 텍스트는 임베딩할 수 없다" if text.blank?

      @adapter.embed(text)
    end

    private

    def default_adapter(mode)
      mode == :live ? Embedding::Adapters::Live.new : Embedding::Adapters::Stub.new
    end
  end
end
