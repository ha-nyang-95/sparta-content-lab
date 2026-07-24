# Embedding::Client 의 모드별 adapter 선택·주입 adapter 사용·blank 방어를 검증
require "test_helper"

class Embedding::ClientTest < ActiveSupport::TestCase
  # embed 호출을 기록하는 fake 어댑터.
  class FakeAdapter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def embed(text)
      @calls << text
      [1.0, 2.0, 3.0]
    end
  end

  test "stub 모드 Client 는 Stub 어댑터를 쓴다" do
    client = Embedding::Client.new(mode: :stub)
    adapter = client.instance_variable_get(:@adapter)
    assert_instance_of Embedding::Adapters::Stub, adapter
  end

  test "live 모드 Client 는 Live 어댑터를 쓴다" do
    client = Embedding::Client.new(mode: :live)
    adapter = client.instance_variable_get(:@adapter)
    assert_instance_of Embedding::Adapters::Live, adapter
  end

  test "주입한 adapter 를 그대로 사용한다" do
    fake = FakeAdapter.new
    client = Embedding::Client.new(adapter: fake)
    result = client.embed("주입 확인")
    assert_equal [1.0, 2.0, 3.0], result
    assert_equal ["주입 확인"], fake.calls
  end

  test "blank 텍스트는 ArgumentError 로 방어한다" do
    client = Embedding::Client.new(adapter: FakeAdapter.new)
    assert_raises(ArgumentError) { client.embed("") }
    assert_raises(ArgumentError) { client.embed(nil) }
  end
end
