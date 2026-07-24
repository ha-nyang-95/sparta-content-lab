# VideoScore 검증 — belongs_to :video 필수·video_id 유니크(영상 1:1, 중복 행 금지)
require "test_helper"

class VideoScoreTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "점수용 채널", category: "직접경쟁", source: "seed")
    @video = @channel.videos.create!(youtube_video_id: "vid_score_1", title: "영상", view_count: 100, is_short: false)
  end

  test "video 가 없으면 유효하지 않다" do
    score = VideoScore.new
    assert_not score.valid?
    assert score.errors[:video].any?
  end

  test "video 가 있으면 저장된다" do
    score = VideoScore.new(video: @video)
    assert score.valid?, score.errors.full_messages.to_sentence
  end

  test "video_id 는 유니크해야 한다 — 같은 영상 두 번째 점수는 무효" do
    VideoScore.create!(video: @video)
    dup = VideoScore.new(video: @video)
    assert_not dup.valid?
    assert dup.errors[:video_id].any?
  end
end
