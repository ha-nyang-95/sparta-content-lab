# Embedding::Adapters::Live 가 키 없을 때 ConfigurationError(보류 마커)를 던지는지 검증
require "test_helper"

class Embedding::Adapters::LiveTest < ActiveSupport::TestCase
  test "키가 없으면 ConfigurationError 를 던진다(보류 마커)" do
    live = Embedding::Adapters::Live.new(api_key: nil)
    assert_raises(Embedding::ConfigurationError) { live.embed("아무 제목") }
  end
end
