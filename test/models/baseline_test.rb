# Baseline 검증 — video_type 화이트리스트·(channel, video_type) 유니크·sample_size 음수 금지
require "test_helper"

class BaselineTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "기준선용 채널", category: "직접경쟁", source: "seed")
  end

  test "video_type 은 VIDEO_TYPES(short/long) 안이어야 한다" do
    baseline = Baseline.new(channel: @channel, video_type: "medium", sample_size: 0)
    assert_not baseline.valid?
    assert baseline.errors[:video_type].any?
  end

  test "유효한 video_type 은 저장된다" do
    baseline = Baseline.new(channel: @channel, video_type: "short", sample_size: 0)
    assert baseline.valid?, baseline.errors.full_messages.to_sentence
  end

  test "video_type 은 채널 내에서 유니크해야 한다" do
    Baseline.create!(channel: @channel, video_type: "long", sample_size: 0)
    dup = Baseline.new(channel: @channel, video_type: "long", sample_size: 0)
    assert_not dup.valid?
    assert dup.errors[:video_type].any?
  end

  test "다른 채널에서는 같은 video_type 을 쓸 수 있다" do
    other = Channel.create!(name: "다른 채널", category: "직접경쟁", source: "seed")
    Baseline.create!(channel: @channel, video_type: "long", sample_size: 0)
    assert Baseline.new(channel: other, video_type: "long", sample_size: 0).valid?
  end

  test "sample_size 는 음수일 수 없다" do
    baseline = Baseline.new(channel: @channel, video_type: "short", sample_size: -1)
    assert_not baseline.valid?
    assert baseline.errors[:sample_size].any?
  end
end
