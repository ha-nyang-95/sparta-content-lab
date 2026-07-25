# videos.list 아이템을 Video 속성 Hash 로 파싱 — 통계 누락 nil 방어(AD-9)·duration 초 정수·원본 폐기
module Youtube
  module VideoAttributes
    # videos.list 단일 item → Video 속성 Hash(심볼 키).
    def self.from(item)
      {
        youtube_video_id: item["id"],
        # 한국어 현지화 제목 우선, 없으면 기본 제목(브라우저 한국어 로케일과 일치).
        title: item.dig("snippet", "localized", "title").presence || item.dig("snippet", "title"),
        view_count: item.dig("statistics", "viewCount")&.to_i,
        like_count: item.dig("statistics", "likeCount")&.to_i,
        comment_count: item.dig("statistics", "commentCount")&.to_i,
        duration: parse_duration(item.dig("contentDetails", "duration")),
        published_at: parse_time(item.dig("snippet", "publishedAt")),
        thumbnail: thumbnail_url(item.dig("snippet", "thumbnails"))
      }
    end

    # ISO8601(PT#H#M#S) → 초 정수. nil/blank/파싱불가/음수 → nil(원본 문자열은 저장 안 함).
    # P0D/PT0S(라이브·프리미어)는 0으로 파싱되며, is_short 분류는 FetchChannelVideos가 0을 거른다.
    def self.parse_duration(iso)
      return nil if iso.blank?

      seconds = ActiveSupport::Duration.parse(iso).to_i
      seconds.negative? ? nil : seconds
    rescue ActiveSupport::Duration::ISO8601Parser::ParsingError, ArgumentError
      nil
    end

    # publishedAt → Time(UTC). nil/파싱불가 → nil.
    def self.parse_time(iso)
      return nil if iso.blank?

      Time.iso8601(iso)
    rescue ArgumentError
      nil
    end

    # 표시에 적당한 크기 우선(medium)으로 썸네일 url, 없으면 상·하위 크기로 폴백, 그래도 없으면 nil.
    def self.thumbnail_url(thumbnails)
      return nil if thumbnails.blank?

      %w[medium high standard maxres default].each do |size|
        url = thumbnails.dig(size, "url")
        return url if url.present?
      end
      nil
    end
  end
end
