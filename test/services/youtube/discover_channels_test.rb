# Youtube::DiscoverChannels — 스텁 search 로 id.channelId 후보 수집·videoId 제외·name 폴백·dedup 검증
require "test_helper"

class Youtube::DiscoverChannelsTest < ActiveSupport::TestCase
  test "call 은 id.channelId 후보를 category·name 과 함께 반환하고 videoId 는 제외한다" do
    candidates = Youtube::DiscoverChannels.new.call

    assert candidates.key?("UC_stub_discovered_channel"), "채널 후보를 수집해야 한다"
    assert_not candidates.key?("vid_stub_discovered"), "videoId 는 후보에 넣지 않는다"

    info = candidates["UC_stub_discovered_channel"]
    assert Channel::CATEGORIES.include?(info[:category]), "category 는 4분류 중 하나"
    # 스텁은 snippet.title 이 없으므로 name 은 channel_id 로 폴백한다.
    assert_equal "UC_stub_discovered_channel", info[:name]
  end

  test "여러 키워드가 같은 스텁 후보를 반환해도 dedup 되어 1채널만 남는다" do
    candidates = Youtube::DiscoverChannels.new.call
    assert_equal 1, candidates.size, "스텁은 query 무시·동일 후보 반환 → dedup 으로 1채널"
  end
end
