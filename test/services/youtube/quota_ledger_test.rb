# QuotaLedger 가 공유 풀·search 버킷을 분리 회계하고 초과 시 QuotaExceeded 를 raise 함을 검증
require "test_helper"

class Youtube::QuotaLedgerTest < ActiveSupport::TestCase
  test "상수는 API 사실(10,000 units / 100 콜)을 고정한다" do
    assert_equal 10_000, Youtube::QuotaLedger::SHARED_DAILY_UNITS
    assert_equal 100, Youtube::QuotaLedger::SEARCH_DAILY_CALLS
  end

  test "charge 가 spent/remaining 을 갱신한다" do
    ledger = Youtube::QuotaLedger.new
    ledger.charge(3, bucket: :shared)
    assert_equal 3, ledger.spent(:shared)
    assert_equal 9_997, ledger.remaining(:shared)
  end

  test "공유 풀 한도 초과 charge 는 QuotaExceeded 를 raise 하고 소비하지 않는다" do
    ledger = Youtube::QuotaLedger.new(shared_limit: 5)
    ledger.charge(5, bucket: :shared)
    assert_raises(Youtube::QuotaExceeded) { ledger.charge(1, bucket: :shared) }
    assert_equal 5, ledger.spent(:shared) # 실패한 charge 는 소비되지 않음
  end

  test "search 버킷은 공유 풀과 독립이다(101번째 search 콜이 별도로 초과)" do
    ledger = Youtube::QuotaLedger.new
    100.times { ledger.charge(1, bucket: :search) }
    assert_equal 0, ledger.spent(:shared)                 # search 가 shared 를 소진하지 않음
    assert_raises(Youtube::QuotaExceeded) { ledger.charge(1, bucket: :search) }
    assert_equal 10_000, ledger.remaining(:shared)        # shared 는 여전히 온전
  end

  test "shared 소진이 search 버킷에 영향을 주지 않는다" do
    ledger = Youtube::QuotaLedger.new(shared_limit: 1)
    ledger.charge(1, bucket: :shared)
    assert_raises(Youtube::QuotaExceeded) { ledger.charge(1, bucket: :shared) }
    assert_equal 100, ledger.remaining(:search) # search 버킷 무손상
  end

  test "알 수 없는 버킷은 ArgumentError" do
    ledger = Youtube::QuotaLedger.new
    assert_raises(ArgumentError) { ledger.charge(1, bucket: :bogus) }
  end
end
