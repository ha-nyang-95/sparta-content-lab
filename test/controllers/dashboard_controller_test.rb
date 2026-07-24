# 대시보드 홈 — 200·읽기 전용·추천 렌더·필터 화이트리스트 폴백·금지 라벨 부재 검증
require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @channel = Channel.create!(name: "韓国語の森 with Aki", category: "직접경쟁", source: "seed", subscriber_count: 1_860_000)
    @video = @channel.videos.create!(youtube_video_id: "vid_#{SecureRandom.hex(4)}", title: "日本人がよく間違える 助詞", view_count: 182_563, is_short: false, published_at: 5.days.ago)
    VideoScore.create!(video: @video, performance_multiple: 2.9, own_match_count: 0, needs_verification: false, rank_eligible: true)
    @rec = Recommendation.create!(topic_label: "일본인이 자주 틀리는 한국어 조사 5가지", opportunity_score: 89.0, rank: 1, reference_video_ids: [@video.id])
  end

  test "GET root 200" do
    get root_path
    assert_response :success
  end

  test "추천이 있으면 topic_label 과 기회 점수를 렌더한다" do
    get root_path
    assert_response :success
    assert_includes @response.body, "일본인이 자주 틀리는 한국어 조사 5가지"
    assert_includes @response.body, "기회 점수"
  end

  test "읽기 전용 — GET 이 Recommendation 을 쓰지 않는다" do
    before = Recommendation.count
    get root_path
    assert_equal before, Recommendation.count
  end

  test "?period=1m 와 ?category 는 200(화이트리스트 안전)" do
    get root_path(period: "1m", category: "한국어교육일반")
    assert_response :success
    get root_path(type: "short", layout: "flat")
    assert_response :success
  end

  test "잘못된 period 는 안전 폴백(200)" do
    get root_path(period: "xxx", category: "drop; --", layout: "zzz")
    assert_response :success
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get root_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end
end
