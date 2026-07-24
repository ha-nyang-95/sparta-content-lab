# 저장 토글 — create/destroy·중복 무해·사용자 격리·미인증 리다이렉트
require "test_helper"

class SavedVideosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @other = users(:two)
    @channel = Channel.create!(name: "토글 채널", category: "직접경쟁", source: "seed", subscriber_count: 10_000)
    @video = @channel.videos.create!(youtube_video_id: "tg_#{SecureRandom.hex(4)}", title: "토글 대상 영상")
  end

  test "POST create 는 저장한다" do
    sign_in_as(@user)
    assert_difference -> { @user.saved_videos.count }, 1 do
      post saved_videos_path(video_id: @video.id)
    end
    assert_response :redirect
  end

  test "POST create 중복은 무해(count 불변)" do
    sign_in_as(@user)
    @user.saved_videos.create!(video: @video)
    assert_no_difference -> { @user.saved_videos.count } do
      post saved_videos_path(video_id: @video.id)
    end
    assert_response :redirect
  end

  test "DELETE destroy 는 해제한다" do
    sign_in_as(@user)
    @user.saved_videos.create!(video: @video)
    assert_difference -> { @user.saved_videos.count }, -1 do
      delete destroy_saved_video_path(video_id: @video.id)
    end
    assert_response :redirect
  end

  test "사용자 격리 — B 의 해제는 A 의 저장을 지우지 않는다" do
    a_save = @user.saved_videos.create!(video: @video)
    sign_in_as(@other)
    assert_no_difference -> { @user.saved_videos.count } do
      delete destroy_saved_video_path(video_id: @video.id)
    end
    assert SavedVideo.exists?(a_save.id)
  end

  test "미인증 create 는 로그인 유도(리다이렉트)" do
    post saved_videos_path(video_id: @video.id)
    assert_redirected_to new_session_path
  end

  test "미인증 destroy 는 로그인 유도(리다이렉트)" do
    delete destroy_saved_video_path(video_id: @video.id)
    assert_redirected_to new_session_path
  end
end
