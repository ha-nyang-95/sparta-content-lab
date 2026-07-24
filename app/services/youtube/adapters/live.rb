# 실 YouTube Data API v3 HTTP 골격 — 키 필요(없으면 raise). 실호출 실데이터 검증은 보류(키 대기)
require "net/http"
require "uri"

module Youtube
  module Adapters
    class Live
      BASE_URL = "https://www.googleapis.com/youtube/v3".freeze
      OPEN_TIMEOUT = 5   # 연결 타임아웃(초)
      READ_TIMEOUT = 15  # 응답 타임아웃(초)

      # endpoint 심볼 → API v3 경로. Stub 어댑터와 같은 엔드포인트 키를 공유한다.
      PATHS = {
        channels_list: "channels",
        playlist_items_list: "playlistItems",
        videos_list: "videos",
        search_list: "search"
      }.freeze

      def initialize(api_key: Youtube::Config.api_key)
        @api_key = api_key
      end

      # fetch(endpoint, params) -> Hash(파싱된 JSON, Stub 과 동일 형태).
      # 키가 없으면 ConfigurationError. HTTP 403(quota/rate)은 RateLimited 로 매핑(Client 가 백오프).
      #
      # 보류(키 대기): 아래 실 HTTP 경로는 골격만 검증됐고, 실 YouTube 응답 대조는 키 도착 후 수행한다.
      def fetch(endpoint, params = {})
        raise Youtube::ConfigurationError, "YOUTUBE_API_KEY 필요 — 보류(키 대기)" if @api_key.blank?

        path = PATHS.fetch(endpoint) do
          raise Youtube::Error, "알 수 없는 endpoint: #{endpoint.inspect}"
        end

        uri = URI.join("#{BASE_URL}/", path)
        uri.query = URI.encode_www_form(params.merge(key: @api_key))

        # 타임아웃을 둬 느린/행 응답이 잡을 무한정 막지 않게 한다.
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.get(uri)
        end

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPForbidden
          # 403은 두 종류다(기술조사 §A): quotaExceeded=일일쿼터 소진(리셋까지 대기·재시도 무의미) vs
          # rate/userRateLimitExceeded=일시 초과(백오프). reason으로 분기해 Client가 올바로 처리하게 한다.
          raise classify_forbidden(response, endpoint)
        else
          raise Youtube::Error, "HTTP #{response.code} (#{endpoint}): #{response.message}"
        end
      end

      private

      # 403 응답 본문의 error.errors[].reason으로 QuotaExceeded/RateLimited를 구분한다.
      def classify_forbidden(response, endpoint)
        reason = begin
          body = JSON.parse(response.body)
          body.dig("error", "errors", 0, "reason").to_s
        rescue JSON::ParserError
          ""
        end

        if reason == "quotaExceeded" || reason == "dailyLimitExceeded"
          Youtube::QuotaExceeded.new("403 #{reason} — 일일 쿼터 소진(#{endpoint})")
        else
          Youtube::RateLimited.new("403 #{reason.presence || 'rateLimit'} (#{endpoint})")
        end
      end
    end
  end
end
