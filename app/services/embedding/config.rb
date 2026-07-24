# Embedding 경계 전용 설정 — 모드(stub/live)·API 키·모델·차원을 ENV/credentials 에서만 읽는다(AD-1)
module Embedding
  module Config
    class << self
      # EMBEDDING_MODE(기본 "stub") → :stub / :live. 알 수 없는 값은 :stub 로 안전 폴백.
      def mode
        (ENV["EMBEDDING_MODE"].presence || "stub").downcase == "live" ? :live : :stub
      end

      # API 키를 ENV(GEMINI_API_KEY) → Rails credentials 순으로 읽는다. 이 경계에서만 읽는다.
      # 키가 없으면 nil(live 어댑터가 ConfigurationError 로 처리).
      def api_key
        ENV["GEMINI_API_KEY"].presence || credentials_api_key
      end

      # master key 부재 등으로 credentials 복호화가 안 되는 환경에서도 nil 로 폴백(예외 전파 방지).
      def credentials_api_key
        Rails.application.credentials.dig(:gemini, :api_key)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::EncryptedFile::MissingKeyError
        nil
      end

      # 임베딩 모델명. GEMINI_EMBEDDING_MODEL 미설정 시 gemini-embedding-001.
      def model
        ENV["GEMINI_EMBEDDING_MODEL"].presence || "gemini-embedding-001"
      end

      # 벡터 차원. gemini-embedding-001 지원 MRL 차원 중 저장 친화적인 768(stub·live·저장 단일값).
      def dimensions
        (ENV["GEMINI_EMBEDDING_DIMENSIONS"].presence || 768).to_i
      end
    end
  end
end
