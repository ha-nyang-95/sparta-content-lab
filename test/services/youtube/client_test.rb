# Youtube::Client 의 배치 50·쿼터 회계·403 지수 백오프·모드 분기를 주입 fake 로 검증
require "test_helper"

class Youtube::ClientTest < ActiveSupport::TestCase
  NOOP_SLEEP = ->(_s) {}

  # 호출을 기록하고 배치별 items 를 반환하는 fake 어댑터.
  class RecordingAdapter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def fetch(endpoint, params)
      @calls << [endpoint, params]
      # id 콤마 개수만큼 item 을 돌려줘 배치 병합을 검증할 수 있게 한다.
      ids = params[:id].to_s.split(",")
      { "items" => ids.map { |i| { "id" => i } } }
    end
  end

  # RateLimited 를 n 회 raise 한 뒤 성공하는 fake 어댑터.
  class FlakyAdapter
    attr_reader :attempts

    def initialize(fail_times:)
      @fail_times = fail_times
      @attempts = 0
    end

    def fetch(_endpoint, _params)
      @attempts += 1
      raise Youtube::RateLimited, "403" if @attempts <= @fail_times

      { "items" => [{ "id" => "ok" }] }
    end
  end

  test "list_videos(120 ids) → 3배치(50/50/20), 3 units :shared 차감, 120 items 병합" do
    adapter = RecordingAdapter.new
    ledger = Youtube::QuotaLedger.new
    client = Youtube::Client.new(adapter: adapter, ledger: ledger, sleep: NOOP_SLEEP)

    ids = (1..120).map { |n| "v#{n}" }
    items = client.list_videos(ids)

    assert_equal 3, adapter.calls.size
    assert_equal [50, 50, 20], adapter.calls.map { |(_, p)| p[:id].split(",").size }
    assert_equal 3, ledger.spent(:shared)
    assert_equal 120, items.size
    assert_instance_of Array, items
  end

  test "list_channels 도 50 배치로 나눠 :shared 를 배치당 1 unit charge" do
    adapter = RecordingAdapter.new
    ledger = Youtube::QuotaLedger.new
    client = Youtube::Client.new(adapter: adapter, ledger: ledger, sleep: NOOP_SLEEP)

    client.list_channels((1..60).map { |n| "c#{n}" })
    assert_equal 2, adapter.calls.size
    assert_equal 2, ledger.spent(:shared)
    assert_equal :channels_list, adapter.calls.first.first
  end

  test "search 는 :search 버킷을 1콜 charge 하고 :shared 를 건드리지 않는다" do
    adapter = Object.new
    def adapter.fetch(_e, _p) = { "items" => [] }
    ledger = Youtube::QuotaLedger.new
    client = Youtube::Client.new(adapter: adapter, ledger: ledger, sleep: NOOP_SLEEP)

    client.search("한국어 발음")
    assert_equal 1, ledger.spent(:search)
    assert_equal 0, ledger.spent(:shared)
  end

  test "403 이 2회 후 성공 → 성공 반환, 총 3 시도, 재시도분 포함 3회 charge" do
    adapter = FlakyAdapter.new(fail_times: 2)
    ledger = Youtube::QuotaLedger.new
    client = Youtube::Client.new(adapter: adapter, ledger: ledger, sleep: NOOP_SLEEP)

    items = client.list_videos(%w[a])
    assert_equal [{ "id" => "ok" }], items
    assert_equal 3, adapter.attempts        # 실패2 + 성공1
    assert_equal 3, ledger.spent(:shared)   # 재시도 소비도 회계
  end

  test "상한 초과 403 은 RateLimited 를 재raise 한다" do
    adapter = FlakyAdapter.new(fail_times: 99)
    client = Youtube::Client.new(adapter: adapter, sleep: NOOP_SLEEP)

    assert_raises(Youtube::RateLimited) { client.list_videos(%w[a]) }
    assert_equal 4, adapter.attempts # 최초 1 + 재시도 3(MAX_RETRIES) 후 재raise
  end

  test "stub 모드 Client 는 Stub 어댑터를 쓰고 fixture 기반 items 를 반환한다" do
    logs = []
    logger_stub = Object.new
    logger_stub.define_singleton_method(:info) { |msg| logs << msg }

    original = Rails.logger
    Rails.logger = logger_stub
    begin
      client = Youtube::Client.new(mode: :stub, sleep: NOOP_SLEEP)
      items = client.list_videos(%w[vid_stub_0001])
      assert_instance_of Array, items
      assert items.any?, "fixture items 가 반환되어야 한다"
      assert logs.any? { |m| m.include?("STUB 모드") }, "STUB 로그가 남아야 한다"
    ensure
      Rails.logger = original
    end
  end

  test "each_playlist_item 은 실 Stub 어댑터에서 종료된다(무한 페이지 방지)" do
    # 정적 스텁이 nextPageToken 을 안 끊으면 쿼터 소진까지 폭주한다 — pageToken 인지로 2페이지에서 종료.
    client = Youtube::Client.new(mode: :stub, sleep: NOOP_SLEEP)
    collected = []
    # 타임아웃 대신 종료 자체를 검증(종료 안 하면 QuotaExceeded/페이지상한으로 실패, 무한루프 아님).
    client.each_playlist_item("UU_stub_uploads") { |item| collected << item }
    assert collected.any?, "페이지 순회로 item 을 하나 이상 yield 해야 한다"
  end

  test "list_videos 는 빈/​nil ids 에 어댑터를 호출하지 않고 [] 를 반환한다" do
    adapter = RecordingAdapter.new
    client = Youtube::Client.new(adapter: adapter, sleep: NOOP_SLEEP)
    assert_equal [], client.list_videos([])
    assert_equal [], client.list_videos(nil)
    assert_equal 0, adapter.calls.size
  end
end
