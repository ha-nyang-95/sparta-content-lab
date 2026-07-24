# SavedVideo — (user, video) 유니크·사용자 격리·belongs_to 검증
require "test_helper"

class SavedVideoTest < ActiveSupport::TestCase
  setup do
    @user  = users(:one)
    @other = users(:two)
    @channel = Channel.create!(name: "저장 채널", category: "직접경쟁", source: "seed", subscriber_count: 10_000)
    @video = @channel.videos.create!(youtube_video_id: "sv_#{SecureRandom.hex(4)}", title: "저장 대상 영상")
  end

  test "같은 사용자가 같은 영상을 두 번 저장하면 무효" do
    @user.saved_videos.create!(video: @video)
    dup = @user.saved_videos.build(video: @video)
    assert_not dup.valid?
    assert_not dup.save
  end

  test "다른 사용자는 같은 영상을 저장할 수 있다" do
    @user.saved_videos.create!(video: @video)
    other_save = @other.saved_videos.build(video: @video)
    assert other_save.valid?
    assert other_save.save
  end

  test "belongs_to user·video" do
    sv = @user.saved_videos.create!(video: @video)
    assert_equal @user, sv.user
    assert_equal @video, sv.video
  end
end
