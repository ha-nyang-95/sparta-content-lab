# 키워드 시드로 search.list(별도 search 버킷)를 호출해 신규 채널 후보를 발굴하는 서비스(AD-11)
module Youtube
  class DiscoverChannels
    def initialize(client: Youtube::Client.new)
      @client = client
    end

    # 각 (category, keyword)로 검색 → items 중 id.channelId 있는 것만 후보로 수집.
    # { channel_id => { category: <문자열>, name: snippet.title || channel_id } } (first-wins).
    def call
      candidates = {}
      Discovery::Config.keywords_by_category.each do |category, keywords|
        Array(keywords).each do |keyword|
          # type=channel 로 채널 결과만 요청(1 unit 동일, Live에서 혼합결과 낭비 방지).
          response = @client.search(keyword, type: "channel")
          collect(response, category, candidates)
        end
      end
      candidates
    rescue Youtube::QuotaExceeded => e
      # search 버킷(100콜/일) 소진 시 하드 실패시키지 않고 지금까지 모은 후보로 부분 진행(스펙 I/O 매트릭스).
      Rails.logger.warn("[Discovery] search 쿼터 소진 — #{candidates.size}개 후보에서 중단: #{e.message}")
      candidates
    end

    private

    def collect(response, category, candidates)
      Array(response["items"]).each do |item|
        channel_id = item.dig("id", "channelId")
        next if channel_id.blank?
        next if candidates.key?(channel_id) # first-wins — 먼저 본 category 유지.

        name = item.dig("snippet", "title").presence || channel_id
        candidates[channel_id] = { category: category, name: name }
      end
    end
  end
end
