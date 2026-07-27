# 경쟁 채널 수동 등록 쓰기 경계 — URL/UC id 또는 @핸들을 해석해 라이브(또는 스텁) 메타로 Channel(source:manual) 생성
module Youtube
  class RegisterChannel
    # UC 로 시작하는 22자 채널 ID(`/channel/UC…` URL 또는 raw). 앞뒤 경계(lookaround)로
    # "MUCH…" 같은 단어 중간 오매칭·23자 이상 과길이 ID 오탐을 막는다.
    CHANNEL_ID_PATTERN = /(?<![\w-])(UC[\w-]{22})(?![\w-])/
    # @핸들(`youtube.com/@handle` URL 또는 raw `@handle`). 2자 이상.
    HANDLE_PATTERN = /@([A-Za-z0-9._-]{2,})/

    # 이름만으로의 검색 해석은 의도적으로 뺀다 — 동명 채널 오매칭 위험이 크다(운영자는 URL 또는 @핸들을 넣는다).
    def initialize(client: Youtube::Client.new)
      @client = client
    end

    # url_or_id 를 UC id → @핸들 순으로 해석하고, 메타를 채워 Channel 을 생성한다.
    # 둘 다 아니면 ArgumentError(호출부 컨트롤러가 flash 로 흡수). 중복·유효성 오류도 호출부가 rescue.
    def call(url_or_id:, name:, category:)
      item = resolve(url_or_id)
      raise ArgumentError, "채널 URL/핸들에서 채널을 찾을 수 없음: #{url_or_id.inspect}" if item.nil? || item["id"].blank?

      snippet = item["snippet"] || {}
      Channel.create!(
        source: "manual",
        is_own: false,
        category: category,
        # 운영자가 이름을 주면 그 이름, 아니면 현지화 제목(한국어)·기본 제목·최후 id 순.
        name: name.presence || snippet.dig("localized", "title").presence || snippet["title"].presence || item["id"],
        youtube_channel_id: item["id"],
        subscriber_count: item.dig("statistics", "subscriberCount")&.to_i,
        uploads_playlist_id: item.dig("contentDetails", "relatedPlaylists", "uploads"),
        thumbnail_url: Youtube::VideoAttributes.thumbnail_url(snippet["thumbnails"])
      )
    end

    private

    # UC id 면 channels.list(id), @핸들이면 channels.list(forHandle) 로 채널 item 을 반환. 둘 다 아니면 nil.
    def resolve(url_or_id)
      if (id = parse_channel_id(url_or_id))
        @client.list_channels([id]).find { |it| it["id"] == id }
      elsif (handle = parse_handle(url_or_id))
        @client.find_channel_by_handle(handle)
      end
    end

    def parse_channel_id(url_or_id)
      CHANNEL_ID_PATTERN.match(url_or_id.to_s)&.captures&.first
    end

    def parse_handle(url_or_id)
      HANDLE_PATTERN.match(url_or_id.to_s)&.captures&.first
    end
  end
end
