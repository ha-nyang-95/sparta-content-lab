# 저장한 영상 화면 — 200·저장 영상 렌더·읽기 전용·empty·사용자 격리·금지 라벨 부재
require "test_helper"

class SavedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @other = users(:two)
    @channel = Channel.create!(name: "저장화면 채널", category: "직접경쟁", source: "seed", subscriber_count: 10_000)
    @video = @channel.videos.create!(
      youtube_video_id: "sc_#{SecureRandom.hex(4)}", title: "저장 화면 영상", view_count: 12_345, published_at: 2.days.ago
    )
    VideoScore.create!(video: @video, performance_multiple: 3.0, own_match_count: 0,
                       needs_verification: false, rank_eligible: true)
  end

  test "GET /saved 200" do
    sign_in_as(@user)
    get saved_path
    assert_response :success
  end

  test "저장한 영상의 제목을 보여준다" do
    sign_in_as(@user)
    @user.saved_videos.create!(video: @video)
    get saved_path
    assert_response :success
    assert_includes @response.body, "저장 화면 영상"
  end

  test "읽기 전용 — GET 이 SavedVideo 를 쓰지 않는다" do
    sign_in_as(@user)
    @user.saved_videos.create!(video: @video)
    before = SavedVideo.count
    get saved_path
    assert_equal before, SavedVideo.count
  end

  test "저장이 없으면 empty 문구" do
    sign_in_as(@user)
    get saved_path
    assert_response :success
    assert_includes @response.body, "저장한 영상이 없습니다."
  end

  test "사용자 격리 — 현재 사용자의 저장만 보인다" do
    @other.saved_videos.create!(video: @video)
    sign_in_as(@user)
    get saved_path
    assert_response :success
    assert_not_includes @response.body, "저장 화면 영상"
    assert_includes @response.body, "저장한 영상이 없습니다."
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    sign_in_as(@user)
    @user.saved_videos.create!(video: @video)
    get saved_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end

  test "미인증은 로그인 유도" do
    get saved_path
    assert_redirected_to new_session_path
  end
end
