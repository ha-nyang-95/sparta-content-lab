# YouTube Data API v3 쿼터 회계 — 공유 units 풀과 search 콜 버킷을 분리 회계(AD-1, 기술조사 §A-1)
module Youtube
  class QuotaLedger
    # API 사실(기술조사 §A-1, 2026-06-01 변경). scoring.yml 튜닝값이 아니라 API 상수.
    SHARED_DAILY_UNITS = 10_000   # videos/channels/playlistItems.list 공유 풀
    SEARCH_DAILY_CALLS = 100      # search.list 별도 버킷(2026-06-01 분리)

    BUCKETS = %i[shared search].freeze

    def initialize(shared_limit: SHARED_DAILY_UNITS, search_limit: SEARCH_DAILY_CALLS)
      @limits = { shared: shared_limit, search: search_limit }
      @spent  = { shared: 0, search: 0 }
    end

    # bucket 에 units 만큼 과금. 한도를 넘기면 소비하지 않고 QuotaExceeded 를 raise(check-before-consume).
    # 재시도도 호출부가 시도마다 charge 하므로 재시도 소비가 원장에 회계된다(AC).
    def charge(units, bucket:)
      validate_bucket!(bucket)
      raise ArgumentError, "units는 0 이상이어야 한다: #{units}" if units.negative?

      if @spent[bucket] + units > @limits[bucket]
        raise Youtube::QuotaExceeded,
          "쿼터 초과(#{bucket}): 사용 #{@spent[bucket]} + 요청 #{units} > 한도 #{@limits[bucket]}"
      end
      @spent[bucket] += units
    end

    def remaining(bucket)
      validate_bucket!(bucket)
      @limits[bucket] - @spent[bucket]
    end

    def spent(bucket)
      validate_bucket!(bucket)
      @spent[bucket]
    end

    private

    def validate_bucket!(bucket)
      return if BUCKETS.include?(bucket)

      raise ArgumentError, "알 수 없는 버킷: #{bucket.inspect} (허용: #{BUCKETS.inspect})"
    end
  end
end
