# OwnVideoMatch — competitor_video/own_video 연관 필수·(competitor,own) 유니크를 검증
require "test_helper"

class OwnVideoMatchTest < ActiveSupport::TestCase
  setup do
    @own_channel = Channel.create!(name: "자사 채널", category: "직접경쟁", source: "seed", is_own: true)
    @comp_channel = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false)
    @own_video = @own_channel.videos.create!(youtube_video_id: "own_1", title: "자사 영상")
    @comp_video = @comp_channel.videos.create!(youtube_video_id: "comp_1", title: "경쟁 영상")
  end

  test "competitor_video·own_video 가 있으면 유효하다" do
    match = OwnVideoMatch.new(competitor_video: @comp_video, own_video: @own_video, similarity: 0.9)
    assert match.valid?, match.errors.full_messages.to_sentence
  end

  test "competitor_video 없이는 무효다" do
    match = OwnVideoMatch.new(own_video: @own_video, similarity: 0.9)
    assert_not match.valid?
    assert match.errors[:competitor_video].any?
  end

  test "own_video 없이는 무효다" do
    match = OwnVideoMatch.new(competitor_video: @comp_video, similarity: 0.9)
    assert_not match.valid?
    assert match.errors[:own_video].any?
  end

  test "(competitor_video_id, own_video_id) 는 유니크여야 한다" do
    OwnVideoMatch.create!(competitor_video: @comp_video, own_video: @own_video, similarity: 0.9)
    dup = OwnVideoMatch.new(competitor_video: @comp_video, own_video: @own_video, similarity: 0.95)
    assert_not dup.valid?
    assert dup.errors[:own_video_id].any?
  end
end
