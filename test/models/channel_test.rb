# Channel 검증·연관·excluded 스코프·youtube_channel_id 유니크(nil 다중 허용)를 검증
require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  def valid_attrs(**over)
    { name: "테스트 채널", category: "직접경쟁", source: "seed" }.merge(over)
  end

  test "유효한 채널은 저장된다" do
    channel = Channel.new(valid_attrs)
    assert channel.valid?, channel.errors.full_messages.to_sentence
  end

  test "category는 4분류가 아니면 무효다" do
    channel = Channel.new(valid_attrs(category: "잘못된분류"))
    assert_not channel.valid?
    assert channel.errors[:category].any?
  end

  test "source는 seed/auto/manual이 아니면 무효다" do
    channel = Channel.new(valid_attrs(source: "unknown"))
    assert_not channel.valid?
    assert channel.errors[:source].any?
  end

  test "name이 없으면 무효다" do
    channel = Channel.new(valid_attrs(name: nil))
    assert_not channel.valid?
    assert channel.errors[:name].any?
  end

  test "youtube_channel_id는 있을 때 유니크여야 한다" do
    Channel.create!(valid_attrs(youtube_channel_id: "UCabc123"))
    dup = Channel.new(valid_attrs(youtube_channel_id: "UCabc123"))
    assert_not dup.valid?
    assert dup.errors[:youtube_channel_id].any?
  end

  test "youtube_channel_id nil인 채널은 여럿 저장된다(다중 NULL)" do
    Channel.create!(valid_attrs(name: "a", youtube_channel_id: nil))
    second = Channel.new(valid_attrs(name: "b", youtube_channel_id: nil))
    assert second.valid?, second.errors.full_messages.to_sentence
    assert second.save
  end

  test "not_excluded 스코프는 excluded 채널을 제외한다" do
    kept = Channel.create!(valid_attrs(name: "포함", excluded: false))
    Channel.create!(valid_attrs(name: "제외", excluded: true))
    ids = Channel.not_excluded.pluck(:id)
    assert_includes ids, kept.id
    assert_equal 0, Channel.not_excluded.where(excluded: true).count
  end

  test "has_many :videos 연관을 가진다" do
    channel = Channel.create!(valid_attrs)
    video = channel.videos.create!(youtube_video_id: "vid_assoc_1", title: "t")
    assert_includes channel.videos, video
  end
end
