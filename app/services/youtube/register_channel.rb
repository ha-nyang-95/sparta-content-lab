# 경쟁 채널 수동 등록 쓰기 경계 — URL/ID 파싱 + 스텁 메타 조회 후 Channel(source:manual) 생성(실 호출 보류·키 대기)
module Youtube
  class RegisterChannel
    # UC 로 시작하는 22자 채널 ID(`/channel/UC…` URL 또는 raw). MVP 범위 — @handle 해석은 라이브 시 확장.
    CHANNEL_ID_PATTERN = /UC[\w-]{22}/

    def initialize(client: Youtube::Client.new)
      @client = client
    end

    # url_or_id 에서 youtube_channel_id 를 파싱하고, 스텁 경계로 메타를 채워 Channel 을 생성한다.
    # 중복(youtube_channel_id 유니크)·유효성 오류는 호출부(컨트롤러)가 rescue 한다 — 여기선 감싸지 않는다.
    def call(url_or_id:, name:, category:)
      id = parse_channel_id(url_or_id)

      # 실 YouTube 라이브 호출은 보류(키 대기) — mode 기본 stub 이라 스텁이 "아직 진짜 아님" 로그를 남긴다.
      items = @client.list_channels([id])
      meta = items.first

      subscriber_count = meta&.dig("statistics", "subscriberCount")&.to_i
      uploads = meta&.dig("contentDetails", "relatedPlaylists", "uploads")

      Channel.create!(
        source: "manual",
        is_own: false,
        category: category,
        name: name.presence || id,
        youtube_channel_id: id,
        subscriber_count: subscriber_count,
        uploads_playlist_id: uploads
      )
    end

    private

    # `/channel/UC…` URL 또는 raw `UC…`/`@handle` 문자열에서 UC 채널 ID 를 추출한다. 없으면 ArgumentError.
    def parse_channel_id(url_or_id)
      match = CHANNEL_ID_PATTERN.match(url_or_id.to_s)
      raise ArgumentError, "채널 ID(UC…) 를 찾을 수 없음: #{url_or_id.inspect}" if match.nil?

      match[0]
    end
  end
end
