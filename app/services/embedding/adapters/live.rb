# 실 Gemini 임베딩 HTTP 골격 — 키 필요(없으면 raise). 실호출 실데이터 검증은 보류(키 대기)
require "net/http"
require "uri"
require "json"

module Embedding
  module Adapters
    class Live
      BASE_URL = "https://generativelanguage.googleapis.com/v1beta".freeze
      OPEN_TIMEOUT = 5   # 연결 타임아웃(초)
      READ_TIMEOUT = 15  # 응답 타임아웃(초)

      def initialize(api_key: Embedding::Config.api_key)
        @api_key = api_key
      end

      # embed(text) -> Array<Float>(길이 Config.dimensions, Stub 과 동일 형태).
      # 키가 없으면 ConfigurationError(보류 마커).
      #
      # 보류(키 대기): 아래 실 HTTP 경로는 골격만 작성됐고, 실 Gemini 응답 대조는 키 도착 후 수행한다.
      # (테스트는 키가 없어 이 경로를 타지 않는다 — ConfigurationError 만 검증한다.)
      def embed(text)
        raise Embedding::ConfigurationError, "GEMINI_API_KEY 없음 — 실 임베딩 호출 보류(키 대기)" if @api_key.blank?

        model = Embedding::Config.model
        uri = URI.join("#{BASE_URL}/", "models/#{model}:embedContent")
        uri.query = URI.encode_www_form(key: @api_key)

        body = {
          model: "models/#{model}",
          content: { parts: [{ text: text.to_s }] },
          outputDimensionality: Embedding::Config.dimensions
        }

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)

        # 타임아웃을 둬 느린/행 응답이 배치를 무한정 막지 않게 한다.
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end

        case response
        when Net::HTTPSuccess
          parsed = JSON.parse(response.body)
          values = parsed.dig("embedding", "values")

          # 응답 형태·차원 검증 — 예상 밖 형태(nil)나 차원 불일치가 nil.pack 크래시·저장 오염으로 번지지 않게 한다.
          unless values.is_a?(Array) && values.length == Embedding::Config.dimensions
            raise Embedding::Error,
              "예상 밖 임베딩 응답(차원 #{values.is_a?(Array) ? values.length : values.class} != #{Embedding::Config.dimensions})"
          end

          normalize(values) # Stub 과 동일 계약(단위 벡터) — 차원<3072 gemini 는 미정규화라 여기서 L2 정규화.
        when Net::HTTPTooManyRequests # 429 RESOURCE_EXHAUSTED — 크레딧/쿼터 소진. 전용 예외로 분리(빌링 경보).
          raise Embedding::QuotaExhausted,
            "Gemini 임베딩 크레딧/쿼터 소진(HTTP 429) — 빌링 충전 후 재수집 필요"
        else
          raise Embedding::Error, "HTTP #{response.code} (embedContent): #{response.message}"
        end
      end

      private

      # L2 정규화(단위 벡터). Stub 어댑터와 저장 계약을 일치시켜 4.2 코사인이 stub·live 를 동일 취급하게 한다.
      def normalize(vector)
        norm = Math.sqrt(vector.sum { |x| x * x })
        return vector if norm.zero?

        vector.map { |x| x / norm }
      end
    end
  end
end
