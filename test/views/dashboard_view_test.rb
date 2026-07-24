# 대시보드 홈 렌더 — 추천 카드 수·정직성 확보 문구·empty·콜드스타트·기간 탭·금지 라벨 부재
require "test_helper"

class DashboardViewTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(User.take) }

  def create_recommendation(rank:, label: "추천 주제 #{rank}", score: 80.0)
    channel = Channel.create!(name: "채널 #{rank}", category: "직접경쟁", source: "seed", subscriber_count: 50_000)
    video = channel.videos.create!(youtube_video_id: "v_#{SecureRandom.hex(4)}", title: "영상 #{rank}", view_count: 12_345, is_short: false, published_at: 3.days.ago)
    VideoScore.create!(video: video, performance_multiple: 3.0, own_match_count: 1, needs_verification: false, rank_eligible: true)
    Recommendation.create!(topic_label: label, opportunity_score: score, rank: rank, reference_video_ids: [video.id])
  end

  test "추천 3개면 카드 3개를 렌더한다" do
    3.times { |i| create_recommendation(rank: i + 1) }
    get root_path
    assert_equal 3, @response.body.scan('data-controller="disclosure"').size
  end

  test "추천 2개면 '이번 주 2개 확보' 정직성 문구를 렌더한다" do
    2.times { |i| create_recommendation(rank: i + 1) }
    get root_path
    assert_includes @response.body, "이번 주 2개 확보"
    assert_equal 2, @response.body.scan('data-controller="disclosure"').size
  end

  test "추천 0개면 empty 상태를 렌더한다" do
    get root_path
    assert_equal 0, @response.body.scan('data-controller="disclosure"').size
    assert_includes @response.body, "0개 확보"
  end

  test "콜드스타트 위젯은 '데이터 수집 중' 자리를 유지한다" do
    get root_path
    assert_includes @response.body, "데이터 수집 중"
  end

  test "기간 탭이 렌더된다" do
    get root_path
    assert_includes @response.body, "최근 1주"
    assert_includes @response.body, "에버그린"
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    create_recommendation(rank: 1)
    get root_path
    assert_not_includes @response.body, "구독자 대비 조회수"
    assert_includes @response.body, "성과 배수(채널 평소 대비)"
  end
end
