# 인기 콘텐츠 — 200·읽기 전용·성과 배수 desc 정렬·필터(유형·카테고리·에버그린)·금지 라벨 부재 검증
require "test_helper"

class PopularControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @channel = Channel.create!(name: "韓国語の森 with Aki", category: "직접경쟁", source: "seed", subscriber_count: 1_860_000)

    @high = make_scored("높은 배수 롱폼", multiple: 9.0, is_short: false, own_match_count: 0)
    @low  = make_scored("낮은 배수 롱폼", multiple: 2.5, is_short: false, own_match_count: 1)
    @short = make_scored("쇼츠 영상", multiple: 4.0, is_short: true, own_match_count: 2)
  end

  def make_scored(title, multiple:, is_short:, own_match_count:, channel: @channel, published_at: 2.days.ago, evergreen: false)
    video = channel.videos.create!(
      youtube_video_id: "vid_#{SecureRandom.hex(4)}",
      title: title, view_count: 120_000, is_short: is_short, published_at: published_at
    )
    VideoScore.create!(video: video, performance_multiple: multiple, own_match_count: own_match_count,
                       needs_verification: false, rank_eligible: true, evergreen_candidate: evergreen)
    video
  end

  test "GET /popular 200" do
    get popular_path
    assert_response :success
  end

  test "성과 배수 desc 로 정렬해 렌더한다" do
    get popular_path
    assert_response :success
    body = @response.body
    assert_operator body.index("높은 배수 롱폼"), :<, body.index("낮은 배수 롱폼"), "9.0배가 2.5배보다 위"
  end

  test "?type=short 는 쇼츠만" do
    get popular_path(type: "short")
    assert_response :success
    assert_includes @response.body, "쇼츠 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "?type=long 는 롱폼만" do
    get popular_path(type: "long")
    assert_response :success
    assert_includes @response.body, "높은 배수 롱폼"
    assert_not_includes @response.body, "쇼츠 영상"
  end

  test "?category 는 그 카테고리 채널만" do
    other = Channel.create!(name: "다른 채널", category: "한국어교육일반", source: "seed", subscriber_count: 5_000)
    make_scored("타 카테고리 영상", multiple: 8.0, is_short: false, own_match_count: 0, channel: other)
    get popular_path(category: "한국어교육일반")
    assert_response :success
    assert_includes @response.body, "타 카테고리 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "?period=evergreen 는 에버그린 후보만" do
    make_scored("에버그린 후보 영상", multiple: 3.0, is_short: false, own_match_count: 0, published_at: 300.days.ago, evergreen: true)
    get popular_path(period: "evergreen")
    assert_response :success
    assert_includes @response.body, "에버그린 후보 영상"
    assert_not_includes @response.body, "높은 배수 롱폼"
  end

  test "excluded 채널은 제외한다" do
    excl = Channel.create!(name: "제외 채널", category: "직접경쟁", source: "seed", subscriber_count: 9_000, excluded: true)
    make_scored("제외 영상", multiple: 20.0, is_short: false, own_match_count: 0, channel: excl)
    get popular_path
    assert_response :success
    assert_not_includes @response.body, "제외 영상"
  end

  test "읽기 전용 — GET 이 VideoScore 를 쓰지 않는다" do
    before = VideoScore.count
    get popular_path
    assert_equal before, VideoScore.count
  end

  test "잘못된 파라미터는 안전 폴백(200)" do
    get popular_path(period: "xxx", category: "drop; --", type: "zzz", layout: "qqq")
    assert_response :success
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get popular_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end
end
