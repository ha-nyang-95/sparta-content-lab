# YouTube 경계 전용 설정 — 모드(stub/live)와 API 키를 ENV/credentials 에서만 읽는다(AD-1)
module Youtube
  module Config
    class << self
      # YOUTUBE_API_MODE(기본 "stub") → :stub / :live. 알 수 없는 값은 :stub 로 안전 폴백.
      def mode
        (ENV["YOUTUBE_API_MODE"].presence || "stub").downcase == "live" ? :live : :stub
      end

      # API 키를 ENV(YOUTUBE_API_KEY) → Rails credentials 순으로 읽는다. 이 경계에서만 읽는다.
      # 키가 없으면 nil(live 어댑터가 ConfigurationError 로 처리).
      def api_key
        ENV["YOUTUBE_API_KEY"].presence || credentials_api_key
      end

      # master key 부재 등으로 credentials 복호화가 안 되는 환경에서도 nil 로 폴백(예외 전파 방지).
      def credentials_api_key
        Rails.application.credentials.dig(:youtube, :api_key)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::EncryptedFile::MissingKeyError
        nil
      end
    end
  end
end
