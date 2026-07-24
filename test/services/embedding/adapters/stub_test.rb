# Embedding::Adapters::Stub 의 차원 정합·결정성·L2 정규화를 검증
require "test_helper"

class Embedding::Adapters::StubTest < ActiveSupport::TestCase
  setup { @stub = Embedding::Adapters::Stub.new }

  test "embed 는 Config.dimensions 길이의 Array 를 반환한다" do
    vec = @stub.embed("한국어 발음 강의")
    assert_instance_of Array, vec
    assert_equal Embedding::Config.dimensions, vec.length
    assert(vec.all? { |x| x.is_a?(Float) })
  end

  test "같은 제목은 같은 벡터(결정적)" do
    assert_equal @stub.embed("같은 제목"), @stub.embed("같은 제목")
  end

  test "다른 제목은 다른 벡터" do
    refute_equal @stub.embed("제목 A"), @stub.embed("제목 B")
  end

  test "벡터는 L2 정규화되어 노름이 약 1.0 이다" do
    vec = @stub.embed("정규화 확인")
    norm = Math.sqrt(vec.sum { |x| x * x })
    assert_in_delta 1.0, norm, 1e-6
  end
end
