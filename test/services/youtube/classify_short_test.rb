# ClassifyShort.short? — 실제 scoring.yml 임계(180) 기반 short/long/경계/nil 판정 검증
require "test_helper"

class Youtube::ClassifyShortTest < ActiveSupport::TestCase
  test "임계 미만 duration 은 short(true)" do
    assert_equal true, Youtube::ClassifyShort.short?(58)
  end

  test "임계 초과 duration 은 long(false)" do
    assert_equal false, Youtube::ClassifyShort.short?(240)
  end

  test "임계와 같으면(≤) short(true)" do
    assert_equal true, Youtube::ClassifyShort.short?(180)
  end

  test "nil 은 미분류(nil)" do
    assert_nil Youtube::ClassifyShort.short?(nil)
  end
end
