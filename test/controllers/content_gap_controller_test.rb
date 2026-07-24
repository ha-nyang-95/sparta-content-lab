# 콘텐츠 갭 — 200·읽기 전용·경쟁만(자사·nil 제외)·분포·구간 필터(기본/폴백)·콜드·금지 라벨 부재 검증
require "test_helper"

class ContentGapControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(User.take)
    @competitor = Channel.create!(name: "경쟁 채널", category: "직접경쟁", source: "seed", is_own: false, subscriber_count: 100_000)
    @own = Channel.create!(name: "우리 채널", category: "직접경쟁", source: "seed", is_own: true, subscriber_count: 5_000)

    make_score(@competitor, "미제작 경쟁 영상", bucket: "not_made", multiple: 8.0, own_match_count: 0)
    make_score(@competitor, "유사1 경쟁 영상", bucket: "one", multiple: 5.0, own_match_count: 1)
    make_score(@competitor, "유사2 경쟁 영상", bucket: "few", multiple: 3.0, own_match_count: 2)
    make_score(@competitor, "포화 경쟁 영상", bucket: "saturated", multiple: 2.0, own_match_count: 3)

    # 자사 영상 — 버킷이 있어도 도넛/리스트에서 제외돼야 한다.
    make_score(@own, "자사 미제작 영상", bucket: "not_made", multiple: 9.0, own_match_count: 0)
    # 미분류(nil) 경쟁 영상 — 분포에서 제외.
    make_score(@competitor, "미분류 경쟁 영상", bucket: nil, multiple: 7.0, own_match_count: 0)
  end

  def make_score(channel, title, bucket:, multiple:, own_match_count:)
    video = channel.videos.create!(
      youtube_video_id: "vid_#{SecureRandom.hex(4)}", title: title,
      view_count: 100_000, is_short: false, published_at: 2.days.ago
    )
    VideoScore.create!(video: video, performance_multiple: multiple, own_match_count: own_match_count,
                       content_gap_bucket: bucket, needs_verification: false, rank_eligible: true)
    video
  end

  test "GET /content-gap 200" do
    get content_gap_path
    assert_response :success
  end

  test "읽기 전용 — GET 이 VideoScore 를 쓰지 않는다" do
    before = VideoScore.count
    get content_gap_path
    assert_equal before, VideoScore.count
  end

  test "자사·미분류 영상은 분포/리스트에서 제외한다" do
    get content_gap_path # 기본 not_made
    assert_response :success
    assert_includes @response.body, "미제작 경쟁 영상"
    assert_not_includes @response.body, "자사 미제작 영상"  # 자사(is_own) 제외
    assert_not_includes @response.body, "미분류 경쟁 영상"  # nil 버킷 제외
  end

  test "?bucket=one 은 그 버킷 영상만 보여준다" do
    get content_gap_path(bucket: "one")
    assert_response :success
    assert_includes @response.body, "유사1 경쟁 영상"
    assert_not_includes @response.body, "미제작 경쟁 영상"
  end

  test "잘못된 bucket 은 not_made 로 폴백한다(200)" do
    get content_gap_path(bucket: "xxx")
    assert_response :success
    assert_includes @response.body, "미제작 경쟁 영상"
    assert_not_includes @response.body, "유사1 경쟁 영상"
  end

  test "콜드스타트 — 분류 0이면 '데이터 수집 중' 자리 유지" do
    VideoScore.update_all(content_gap_bucket: nil)
    get content_gap_path
    assert_response :success
    assert_includes @response.body, "데이터 수집 중"
  end

  test "금지 라벨 '구독자 대비 조회수' 가 없다" do
    get content_gap_path
    assert_not_includes @response.body, "구독자 대비 조회수"
  end
end
