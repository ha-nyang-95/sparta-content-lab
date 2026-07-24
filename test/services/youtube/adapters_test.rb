# Stub/Live 어댑터 계약과 녹화 fixture 의 실 API 형태(nil 방어용 누락 케이스 포함)를 검증
require "test_helper"

class Youtube::AdaptersTest < ActiveSupport::TestCase
  test "Stub 어댑터는 endpoint 별 fixture 를 파싱해 반환하고 STUB 로그를 남긴다" do
    logs = []
    logger_stub = Object.new
    logger_stub.define_singleton_method(:info) { |msg| logs << msg }
    original = Rails.logger
    Rails.logger = logger_stub
    begin
      res = Youtube::Adapters::Stub.new.fetch(:channels_list)
      assert res["items"].is_a?(Array)
      assert logs.any? { |m| m.include?("STUB 모드") && m.include?("channels_list") }
    ensure
      Rails.logger = original
    end
  end

  test "Stub 어댑터는 알 수 없는 endpoint 에 Youtube::Error" do
    assert_raises(Youtube::Error) { Youtube::Adapters::Stub.new.fetch(:bogus) }
  end

  test "Live 어댑터는 키가 없으면 ConfigurationError(네트워크 미접촉)" do
    error = assert_raises(Youtube::ConfigurationError) do
      Youtube::Adapters::Live.new(api_key: nil).fetch(:videos_list, id: "x")
    end
    assert_match(/보류\(키 대기\)/, error.message)
  end

  test "channels fixture: uploads 경로와 subscriberCount 가 존재한다" do
    res = Youtube::Adapters::Stub.new.fetch(:channels_list)
    item = res["items"].first
    assert item.dig("contentDetails", "relatedPlaylists", "uploads").present?
    assert item.dig("statistics", "subscriberCount").present?
  end

  test "videos fixture: 파싱되고 duration 은 ISO8601, like/comment 누락 아이템이 최소 1개" do
    res = Youtube::Adapters::Stub.new.fetch(:videos_list)
    items = res["items"]
    assert items.all? { |v| v.dig("contentDetails", "duration").match?(/\APT/) }

    hidden = items.select do |v|
      stats = v["statistics"] || {}
      !stats.key?("likeCount") && !stats.key?("commentCount")
    end
    assert hidden.any?, "likeCount·commentCount 둘 다 누락된 아이템이 최소 1개 있어야 한다"

    # 회원 전용류: viewCount 누락 아이템도 하방 nil 방어용으로 존재
    assert items.any? { |v| !(v["statistics"] || {}).key?("viewCount") }
  end

  test "playlist fixture: videoId 와 nextPageToken 을 가진다" do
    res = Youtube::Adapters::Stub.new.fetch(:playlist_items_list)
    assert res["items"].first.dig("contentDetails", "videoId").present?
    assert res["nextPageToken"].present?
  end
end
