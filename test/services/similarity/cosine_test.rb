# Similarity::Cosine — 동일/직교/반대·비정규 벡터(분모 계산)·nil·길이 불일치·zero 벡터 방어를 검증
require "test_helper"

class Similarity::CosineTest < ActiveSupport::TestCase
  test "동일 벡터는 코사인 1.0" do
    assert_in_delta 1.0, Similarity::Cosine.between([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]), 1e-9
  end

  test "직교 벡터는 코사인 0.0" do
    assert_in_delta 0.0, Similarity::Cosine.between([1.0, 0.0], [0.0, 1.0]), 1e-9
  end

  test "반대 벡터는 코사인 -1.0" do
    assert_in_delta(-1.0, Similarity::Cosine.between([1.0, 0.0], [-1.0, 0.0]), 1e-9)
  end

  test "비정규 벡터도 분모를 계산해 올바른 코사인을 낸다([3,0] vs [5,0] → 1.0)" do
    assert_in_delta 1.0, Similarity::Cosine.between([3.0, 0.0], [5.0, 0.0]), 1e-9
  end

  test "nil 입력은 nil" do
    assert_nil Similarity::Cosine.between(nil, [1.0, 0.0])
    assert_nil Similarity::Cosine.between([1.0, 0.0], nil)
  end

  test "길이 불일치는 nil" do
    assert_nil Similarity::Cosine.between([1.0, 0.0], [1.0, 0.0, 0.0])
  end

  test "zero 벡터는 nil(norm 0 방어)" do
    assert_nil Similarity::Cosine.between([0.0, 0.0], [1.0, 0.0])
  end

  test "빈 벡터는 nil" do
    assert_nil Similarity::Cosine.between([], [])
  end
  test "NaN 성분이 있으면 nil(비유한 방어)" do
    assert_nil Similarity::Cosine.between([Float::NAN, 0.0], [1.0, 0.0])
  end

  test "float 드리프트로 |코사인|>1 이어도 [-1,1] 로 clamp 된다" do
    # 동일 벡터의 코사인은 1.0 을 넘지 않는다(clamp 확인).
    v = [0.3, 0.4, 0.5]
    assert_operator Similarity::Cosine.between(v, v), :<=, 1.0
    assert_in_delta 1.0, Similarity::Cosine.between(v, v), 1e-9
  end

  test "unit 은 단위 벡터를 반환하고 nil·빈·zero-norm 은 nil" do
    u = Similarity::Cosine.unit([3.0, 4.0])
    assert_in_delta 1.0, Math.sqrt(u.sum { |x| x * x }), 1e-9
    assert_nil Similarity::Cosine.unit(nil)
    assert_nil Similarity::Cosine.unit([])
    assert_nil Similarity::Cosine.unit([0.0, 0.0])
  end

end
