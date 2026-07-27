# 영상 분석 경계 설정 — 모드(live/stub)·Gemini 생성 모델·키(임베딩과 같은 GEMINI 키 재사용)
module Analysis
  module Config
    class << self
      # ANALYSIS_MODE 기본 live(dev 는 키 보유). test 환경은 test.rb 가 stub 강제.
      def mode
        (ENV["ANALYSIS_MODE"].presence || "live").downcase == "stub" ? :stub : :live
      end

      # 영상 이해가 아니라 텍스트(자막) 분석용 생성 모델. gemini-2.5-flash 는 신규 차단이라 flash-latest 별칭.
      def model
        ENV["ANALYSIS_MODEL"].presence || "gemini-flash-latest"
      end

      # GEMINI_API_KEY 를 이 경계에서 직접 읽는다(ENV → credentials). 임베딩과 같은 키지만 경계별 자기완결(AD-1).
      def api_key
        ENV["GEMINI_API_KEY"].presence || credentials_api_key
      end

      def credentials_api_key
        Rails.application.credentials.dig(:gemini, :api_key)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::EncryptedFile::MissingKeyError
        nil
      end
    end
  end
end
