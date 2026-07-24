# Video 검증·연관·nil 통계 방어(view/like/comment nil 허용)를 검증
require "test_helper"

class VideoTest < ActiveSupport::TestCase
  setup do
    @channel = Channel.create!(name: "영상용 채널", category: "직접경쟁", source: "seed")
  end

  test "유효한 영상은 저장된다" do
    video = @channel.videos.new(youtube_video_id: "vid_valid_1", title: "제목")
    assert video.valid?, video.errors.full_messages.to_sentence
  end

  test "youtube_video_id는 유니크여야 한다" do
    @channel.videos.create!(youtube_video_id: "vid_dup_1")
    dup = @channel.videos.new(youtube_video_id: "vid_dup_1")
    assert_not dup.valid?
    assert dup.errors[:youtube_video_id].any?
  end

  test "view_count/like_count/comment_count/duration이 nil이어도 유효하고 저장된다(nil 방어)" do
    video = @channel.videos.new(
      youtube_video_id: "vid_nil_stats",
      title: "회원 전용",
      view_count: nil,
      like_count: nil,
      comment_count: nil,
      duration: nil
    )
    assert video.valid?, video.errors.full_messages.to_sentence
    assert video.save
    video.reload
    assert_nil video.view_count
    assert_nil video.duration
  end

  test "belongs_to :channel — 채널 없이는 무효다" do
    video = Video.new(youtube_video_id: "vid_no_channel")
    assert_not video.valid?
    assert video.errors[:channel].any?
  end
end
