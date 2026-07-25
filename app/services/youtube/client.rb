# 모든 YouTube Data API v3 호출의 단일 공개 경계 — 배치 50·쿼터 원장·403 지수 백오프 소유(AD-1)
module Youtube
  class Client
    BATCH_SIZE = 50          # channels.list / videos.list ID 배치 상한(기술조사 §A-3)
    BACKOFF_DELAYS = [1, 2, 4].freeze  # 지수 백오프 초(재시도 1·2·3회차)
    MAX_RETRIES = BACKOFF_DELAYS.length # 403 백오프 재시도 상한(딜레이 수와 결합해 오설정 방지)
    MAX_PAGES = 1_000        # 페이지네이션 안전 상한(어댑터가 nextPageToken을 안 끊는 폭주 방지)

    # adapter 는 mode 로 기본 선택하되 테스트가 fake 를 주입할 수 있다.
    # sleep 은 주입 가능(테스트는 무대기 proc). 재시도마다 쿼터를 다시 charge 한다(AC).
    def initialize(mode: Youtube::Config.mode, ledger: QuotaLedger.new, adapter: nil,
                   sleep: ->(s) { Kernel.sleep(s) })
      @ledger = ledger
      @adapter = adapter || default_adapter(mode)
      @sleep = sleep
    end

    # 표시 로케일 — 앱 운영 언어(한국어). snippet.localized.* 가 이 언어로 현지화된 제목을 채운다
    # (없으면 채널/영상 기본 언어로 폴백). 브라우저(한국어 로케일)가 보여주는 이름과 일치시킨다.
    DISPLAY_LOCALE = "ko".freeze

    # channels.list — ids 를 50개씩 배치, 배치당 1 unit(:shared). 병합된 items 배열을 반환한다.
    # snippet 포함 — 채널 썸네일(아바타)·현지화 제목 수집용. part·hl 추가는 쿼터 비용 불변(호출당 1 unit).
    def list_channels(ids)
      batched_items(ids, :channels_list, part: "snippet,contentDetails,statistics", hl: DISPLAY_LOCALE)
    end

    # videos.list — ids 를 50개씩 배치, 배치당 1 unit(:shared). 병합된 items 배열을 반환한다.
    def list_videos(ids)
      batched_items(ids, :videos_list, part: "snippet,statistics,contentDetails", hl: DISPLAY_LOCALE)
    end

    # playlistItems.list — 단일 페이지(1 unit :shared)를 그대로 반환(items + nextPageToken).
    # 페이지네이션 루프는 호출부(2.3)가 each_playlist_item 또는 page_token 재호출로 수행한다.
    def list_playlist_items(playlist_id, page_token: nil)
      params = { part: "contentDetails", playlistId: playlist_id, maxResults: BATCH_SIZE }
      params[:pageToken] = page_token if page_token
      fetch_with_quota(:playlist_items_list, params, units: 1, bucket: :shared)
    end

    # uploads 재생목록 전체를 페이지네이션으로 순회하며 각 페이지 item 을 yield(페이지당 1 unit).
    def each_playlist_item(playlist_id)
      return enum_for(:each_playlist_item, playlist_id) unless block_given?

      token = nil
      pages = 0
      loop do
        page = list_playlist_items(playlist_id, page_token: token)
        Array(page["items"]).each { |item| yield item }
        token = page["nextPageToken"]
        pages += 1
        break if token.blank?

        # 어댑터가 nextPageToken을 끊지 않으면 쿼터를 소진할 때까지 도는 것을 막는다.
        raise Youtube::Error, "playlistItems 페이지 상한(#{MAX_PAGES}) 초과 — #{playlist_id}" if pages >= MAX_PAGES
      end
    end

    # search.list — :search 버킷에서 콜당 1 회 charge(공유 풀과 무관). 응답 Hash 를 그대로 반환.
    def search(query, params = {})
      merged = params.merge(part: "snippet", q: query, maxResults: BATCH_SIZE)
      fetch_with_quota(:search_list, merged, units: 1, bucket: :search)
    end

    private

    def default_adapter(mode)
      mode == :live ? Youtube::Adapters::Live.new : Youtube::Adapters::Stub.new
    end

    # ids 를 50개씩 나눠 endpoint 를 호출하고 items 를 병합해 반환한다.
    def batched_items(ids, endpoint, base_params)
      Array(ids).each_slice(BATCH_SIZE).flat_map do |slice|
        params = base_params.merge(id: slice.join(","))
        response = fetch_with_quota(endpoint, params, units: 1, bucket: :shared)
        Array(response["items"])
      end
    end

    # 쿼터를 charge 하고 어댑터를 호출한다. 403(RateLimited)은 지수 백오프로 재시도하며,
    # 각 시도마다 쿼터를 다시 charge 한다(재시도 소비 회계, AC). 상한 초과 시 재raise.
    def fetch_with_quota(endpoint, params, units:, bucket:)
      attempt = 0
      begin
        @ledger.charge(units, bucket: bucket)
        @adapter.fetch(endpoint, params)
      rescue Youtube::RateLimited
        attempt += 1
        raise if attempt > MAX_RETRIES

        @sleep.call(BACKOFF_DELAYS[attempt - 1] || BACKOFF_DELAYS.last)
        retry
      end
    end
  end
end
