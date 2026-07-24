# Scoring::SubscriberBand — 4티어 경계값(포함 하한 1만/10만/50만)·nil 방어·config 경계 읽기·라벨 검증
require "test_helper"

class Scoring::SubscriberBandTest < ActiveSupport::TestCase
  test "티어 매핑 — config 경계로 포함 하한 분류(하드코딩 회귀 포착)" do
    inputs   = [0, 9999, 10000, 100000, 500000, 2_000_000, nil]
    expected = [0, 0,    1,     2,      3,      3,         nil]
    assert_equal expected, inputs.map { |n| Scoring::SubscriberBand.tier(n) }
  end

  test "티어0 — 9,999는 티어 0" do
    assert_equal 0, Scoring::SubscriberBand.tier(9_999)
  end

  test "경계 1만 — 정확히 10,000은 티어 1(포함 하한)" do
    assert_equal 1, Scoring::SubscriberBand.tier(10_000)
  end

  test "경계 10만 — 정확히 100,000은 티어 2(포함 하한)" do
    assert_equal 2, Scoring::SubscriberBand.tier(100_000)
  end

  test "경계 50만 — 정확히 500,000은 티어 3(포함 하한)" do
    assert_equal 3, Scoring::SubscriberBand.tier(500_000)
  end

  test "티어3 상단 — 2,000,000은 티어 3" do
    assert_equal 3, Scoring::SubscriberBand.tier(2_000_000)
  end

  test "nil 방어 — subscriber_count nil이면 티어 nil, 예외 없음" do
    assert_nil Scoring::SubscriberBand.tier(nil)
  end

  test "label — 티어별 표시 라벨" do
    assert_equal "<1만", Scoring::SubscriberBand.label(9_999)
    assert_equal "1만~10만", Scoring::SubscriberBand.label(10_000)
    assert_equal "50만+", Scoring::SubscriberBand.label(2_000_000)
  end

  test "label — nil이면 nil" do
    assert_nil Scoring::SubscriberBand.label(nil)
  end

  test "불변식 — LABELS 개수는 subscriber_bands 티어 수(경계+1)와 일치한다" do
    bands = Scoring::Config.fetch(:subscriber_bands)
    assert_equal bands.length + 1, Scoring::SubscriberBand::LABELS.length,
      "밴드 경계를 바꾸면 LABELS도 함께 갱신해야 한다(라벨 드리프트·인덱스 초과 방지)"
  end
end
